/**
 * Class functionality - This class demonstrating how to sign requests to Amazon S3 using
 *      query string parameters.
 *
 * @author - Tejashree Chavan
 *
 */
public with sharing class AWS4SignerForQueryParameterAuth extends AWS4SignerBase{
   //Constructor
    public AWS4SignerForQueryParameterAuth(URL endpointUrl, String httpMethod,
        String serviceName, String regionName) {
        super(endpointUrl, httpMethod, serviceName, regionName);
    }
    /**
     * Computes an AWS4 authorization for a request, suitable for embedding in
     * query parameters.
     * 
     * @param headers - The request headers; 'Host' and 'X-Amz-Date' will be added to
     *      this set.
     * @param queryParameters - Any query parameters that will be added to the endpoint. The
     *      parameters should be specified in canonical format.
     * @param bodyHash - Precomputed SHA256 hash of the request body content; this
     *      value should also be set as the header 'X-Amz-Content-SHA256'for non-streaming uploads.
     * @param awsAccessKey - The user's AWS Access Key.
     * @param awsSecretKey - The user's AWS Secret Key.
     * @return The computed authorization string for the request. This value needs to be set 
     *      as the header 'Authorization' on the subsequent HTTP request.
     */
    public String computeSignature(
            Map<String, String> headers,
            Map<String, String> queryParameters,
            String bodyHash,
            String awsAccessKey,
            String awsSecretKey
    ) {
        /* first get the date and time for the subsequent request, and convert
         *      to ISO 8601 format for use in signature generation
         */
        dateTimeFormat=Datetime.now();
        //dateTimeFormat=datetime.newInstance(2014, 10, 16,11,53,55);
        String dateTimeStamp = dateTimeFormat.formatGmt(ISO8601BasicFormat);
        // make sure "Host" header is added
        String hostHeader = endpointUrl.getHost();
        Integer port = endpointUrl.getPort();
        if ( port > -1 ) {
            hostHeader +=':' +string.valueof(port);
        }
        headers.put('Host', hostHeader);

        /* canonicalized headers need to be expressed in the query parameters
         * processed in the signature
         */
        String canonicalizedHeaderNames = getCanonicalizeHeaderNames(headers);
        String canonicalizedHeaders = getCanonicalizedHeaderString(headers);
        // we need scope as part of the query parameters
        dateStampFormat=datetime.now();
        //dateStampFormat=datetime.newInstance(2014, 10, 16,11,53,55);
        String dateStamp = dateStampFormat.formatGmt(DateStringFormat);
        String scope =  dateStamp + '/' + regionName + '/' + serviceName + '/' + TERMINATOR;

        // add the fixed authorization params required by Signature V4
        if(serviceName.Equals('sqs')) {
        queryParameters.put('Action','ReceiveMessage');
        }
        
        queryParameters.put('X-Amz-Algorithm', SCHEME + '-' + ALGORITHM);
        queryParameters.put('X-Amz-Credential', awsAccessKey + '/' + scope);
        
        // x-amz-date is now added as a query parameter, but still need to be in ISO8601 basic form
        queryParameters.put('X-Amz-Date', dateTimeStamp);

        queryParameters.put('X-Amz-SignedHeaders', canonicalizedHeaderNames);

        // build the expanded canonical query parameter string that will go into the
        // signature computation
        String canonicalizedQueryParameters = getCanonicalizedQueryString(queryParameters);
        // express all the header and query parameter data as a canonical request string
        String canonicalRequest = getCanonicalRequest(endpointUrl, httpMethod,
                canonicalizedQueryParameters, canonicalizedHeaderNames,
                canonicalizedHeaders, bodyHash,serviceName);
        System.debug('--------- Canonical request --------');
        System.debug(canonicalRequest);
        System.debug('------------------------------------');

        // construct the string to be signed
        String stringToSign = getStringToSign(SCHEME, ALGORITHM, 
                dateTimeStamp, scope, canonicalRequest);
        System.debug('--------- String to sign -----------');
        System.debug(stringToSign);
        System.debug('------------------------------------');

        // compute the signing key
        String key =SCHEME + awsSecretKey;
        Blob kSecret = Blob.valueOf(key);
        blob kDate = sign(dateStamp, kSecret, 'HmacSHA256');
        blob kRegion = sign(regionName, kDate, 'HmacSHA256');
        blob kService = sign(serviceName, kRegion, 'HmacSHA256');
        blob kSigning = sign(TERMINATOR, kService, 'HmacSHA256');
        blob signature = sign(stringToSign, kSigning, 'HmacSHA256');
        // form up the authorization parameters for the caller to place in the query string
        String authString = '';
        if(serviceName.Equals('sqs')) {
         authString += 'Action=' + queryParameters.get('Action')+'&';
        }
        authString += 'X-Amz-Algorithm=' + queryParameters.get('X-Amz-Algorithm');
        authString += '&X-Amz-Credential=' + queryParameters.get('X-Amz-Credential');
        authString +='&X-Amz-Date=' + queryParameters.get('X-Amz-Date');
        authString +='&X-Amz-Expires=' + queryParameters.get('X-Amz-Expires');
        authString +='&X-Amz-SignedHeaders=' + queryParameters.get('X-Amz-SignedHeaders');
        authString +='&X-Amz-Signature=' + EncodingUtil.convertToHex(signature);

        system.debug('----------------auth String---------------'+authString);

        return authString;

    }
}