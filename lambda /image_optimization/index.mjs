// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import { GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import Sharp from 'sharp';

const s3Client = new S3Client({ region: process.env.s3BucketRegion });
const S3_ORIGINAL_IMAGE_BUCKET = process.env.originalImageBucketName;
const S3_TRANSFORMED_IMAGE_BUCKET = process.env.transformedImageBucketName;
const TRANSFORMED_IMAGE_CACHE_TTL = process.env.transformedImageCacheTTL;
const MAX_IMAGE_SIZE = parseInt(process.env.maxImageSize);

export const handler = async (event) => {
    // Validate if this is a GET request
    if (!event.requestContext || !event.requestContext.http || !(event.requestContext.http.method === 'GET')) return sendError(400, 'Only GET method is supported', event);

    // Extracting the path and query parameters
    const path = event.requestContext.http.path;
    const queryStringParameters = event.queryStringParameters || {};
    
    // The image path from the URL
    const imagePath = path.startsWith('/') ? path.substring(1) : path;

    // Check if the requested file should be processed or ignored
    const fileExtension = path.split('.').pop().toLowerCase();
    const supportedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif', 'svg'];

    if (!supportedExtensions.includes(fileExtension)) {
        // If the file is not an image, return a 302 redirect to the original URL
        return {
            statusCode: 302,
            headers: {
                'Location': path,
                'Cache-Control': 'no-cache'
            }
        };
    }

    // Extracting operations from query parameters
    const width = queryStringParameters.width ? parseInt(queryStringParameters.width) : null;
    const height = queryStringParameters.height ? parseInt(queryStringParameters.height) : null;
    const format = queryStringParameters['image-type'] || null;
    const quality = queryStringParameters.quality ? parseInt(queryStringParameters.quality) : null;

    var startTime = performance.now();
    let originalImageBody;
    let contentType;
    
    try {
        const getOriginalImageCommand = new GetObjectCommand({ Bucket: S3_ORIGINAL_IMAGE_BUCKET, Key: imagePath });
        const getOriginalImageCommandOutput = await s3Client.send(getOriginalImageCommand);
        console.log(`Got response from S3 for ${imagePath}`);

        originalImageBody = await getOriginalImageCommandOutput.Body.transformToByteArray();
        contentType = getOriginalImageCommandOutput.ContentType;
    } catch (error) {
        return sendError(500, 'Error downloading original image', error);
    }

    let transformedImage = Sharp(originalImageBody, { failOn: 'none', animated: true });
    const imageMetadata = await transformedImage.metadata();

    var timingLog = 'img-download;dur=' + parseInt(performance.now() - startTime);
    startTime = performance.now();

    try {
        if (width || height) {
           transformedImage = transformedImage.resize({
               width: width,
               height: height,
               fit: Sharp.fit.inside,
               withoutEnlargement: true
            });
        }
        if (imageMetadata.orientation) transformedImage = transformedImage.rotate();
        
        if (format) {
            var isLossy = false;
            switch (format) {
                case 'jpeg': contentType = 'image/jpeg'; isLossy = true; break;
                case 'gif': contentType = 'image/gif'; break;
                case 'webp': contentType = 'image/webp'; isLossy = true; break;
                case 'png': contentType = 'image/png'; break;
                case 'avif': contentType = 'image/avif'; isLossy = true; break;
                default: contentType = 'image/jpeg'; isLossy = true;
            }
            if (quality && isLossy) {
                transformedImage = transformedImage.toFormat(format, { quality: quality });
            } else {
                transformedImage = transformedImage.toFormat(format);
            }
        } else {
            if (contentType === 'image/svg+xml') contentType = 'image/png';
        }
        
        transformedImage = await transformedImage.toBuffer();
    } catch (error) {
        return sendError(500, 'Error transforming image', error);
    }
    
    timingLog = timingLog + ',img-transform;dur=' + parseInt(performance.now() - startTime);
    const imageTooBig = Buffer.byteLength(transformedImage) > MAX_IMAGE_SIZE;
    
    if (S3_TRANSFORMED_IMAGE_BUCKET) {
        startTime = performance.now();
        try {
            const metadata = {
            'cache-control': TRANSFORMED_IMAGE_CACHE_TTL,
            'width': width ? width.toString() : 'empty',
            'height': height ? height.toString() : 'empty',
            'quality': quality ? quality.toString() : 'empty'
            };
            const putImageCommand = new PutObjectCommand({
                Body: transformedImage,
                Bucket: S3_TRANSFORMED_IMAGE_BUCKET,
                Key: imagePath,
                ContentType: contentType,
                Metadata: metadata
            });
            await s3Client.send(putImageCommand);
            timingLog = timingLog + ',img-upload;dur=' + parseInt(performance.now() - startTime);
            
            if (imageTooBig) {
                return {
                    statusCode: 302,
                    headers: {
                        'Location': '/' + imagePath + '?' + new URLSearchParams(queryStringParameters).toString(),
                        'Cache-Control': 'private,no-store',
                        'Server-Timing': timingLog
                    }
                };
            }
        } catch (error) {
            logError('Could not upload transformed image to S3', error);
        }
    }

    if (imageTooBig) {
        return sendError(403, 'Requested transformed image is too big', '');
    } else {
        return {
            statusCode: 200,
            body: transformedImage.toString('base64'),
            isBase64Encoded: true,
            headers: {
                'Content-Type': contentType,
                'Cache-Control': TRANSFORMED_IMAGE_CACHE_TTL,
                'Server-Timing': timingLog
            }
        };
    }
};

function sendError(statusCode, body, error) {
    logError(body, error);
    return { statusCode, body };
}

function logError(body, error) {
    console.log('APPLICATION ERROR', body);
    console.log(error);
}
