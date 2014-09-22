/**
 * Class functionality - This class computes the signing URL for Accessing Amazon services
 *
 * @author - Tejashree Chavan
 *
 */
public with sharing class PresignedUrlSample {
     /**
     * Construct a basic presigned url to the object '/ExampleObject.txt' in the
     * given bucket and region using path-style object addressing. The signature
     * V4 authorization data is embedded in the url as query parameters.
     */
    public  String  getPresignedUrlToS3Object(
            String awsAccessKey,
            String endPointUrl,
            String fileName,
            String regionName,
            String mode,
            String awsSecretKey,
            String service
    ) {
        URL endpoint;
        try {
        endpoint = new URL(endPointUrl+fileName);
        } 
        catch (Exception e) {
        system.debug('Unable to parse service endpoint: ' + e.getMessage());
        }

        // construct the query parameter string to accompany the url
        Map<String, String> queryParams = new Map<String, String>();

        // for SignatureV4, the max expiry for a presigned url is 7 days,
        // expressed in seconds
        Integer expiresIn = 7 * 24 * 60 * 60;
        queryParams.put('X-Amz-Expires', '' + expiresIn);

        // we have no headers for this sample, but the signer will add 'host'
        Map<String, String> headers = new Map<String, String>();

        AWS4SignerForQueryParameterAuth signer = new AWS4SignerForQueryParameterAuth(
            endpoint, mode, service, regionName);
        String authorizationQueryParameters = signer.computeSignature(headers, 
            queryParams,
            AWS4SignerBase.UNSIGNED_PAYLOAD, 
            awsAccessKey, 
            awsSecretKey);

        // build the presigned url to incorporate the authorization elements as query parameters
        String presignedUrl = endpoint.toString() + '?' + authorizationQueryParameters;
        System.debug('--------- Computed presigned url ---------');
        presignedUrl=presignedUrl.replace('Url:[delegate=','');
        presignedUrl=presignedUrl.replace(']','');
        System.debug(presignedUrl);
        System.debug('------------------------------------------');

        return presignedUrl;
    }
}