/**
 * Class functionality - This class contains common methods and properties for all AWS4 signer 
        variants.Computes Canonical string,String to sign and signature.
 *
 * @author - Tejashree Chavan
 *
 */
public virtual class AWS4SignerBase {
 //SHA256 hash of an empty request body
    public static final String EMPTY_BODY_SHA256 =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    public static final String UNSIGNED_PAYLOAD = 'UNSIGNED-PAYLOAD';

    public static final String SCHEME = 'AWS4';
    public static final String ALGORITHM = 'HMAC-SHA256';
    public static final String TERMINATOR = 'aws4_request';

    // Format strings for the date/time and date stamps required during signing
    public static String ISO8601BasicFormat = 'yyyyMMdd\'T\'HHmmss\'Z\'';
    public static String DateStringFormat = 'yyyyMMdd';

    protected URL endpointUrl;
    protected String httpMethod;
    protected String serviceName;
    protected String regionName;
    
    protected  Datetime dateTimeFormat;
    protected  Datetime dateStampFormat;

    /**
     * Create a new AWS V4 signer.
     * 
     * @param endpointUri - The service endpoint, including the path to any resource.
     * @param httpMethod -The HTTP verb for the request, e.g. GET.
     * @param serviceName - The signing name of the service, e.g. 's3'.
     * @param regionName - The system name of the AWS region associated with the
        endpoint, e.g. us-east-1.
     */
    public AWS4SignerBase(URL endpointUrl, String httpMethod,
            String serviceName, String regionName
    ) {
        this.endpointUrl = endpointUrl;
        this.httpMethod = httpMethod;
        this.serviceName = serviceName;
        this.regionName = regionName;
    }

    public AWS4SignerBase()
    {}

    /**
     * Returns the canonical collection of header names that will be included in
     * the signature. For AWS4, all header names must be included in the process
     * in sorted canonicalized order.
     */
    public static String getCanonicalizeHeaderNames(Map<String, String> headers) {
        List<String> sortedHeaders = new List<String>();
        sortedHeaders.addAll(headers.keySet());
        sortedHeaders.sort();

        String buffer ='';
        for (String header : sortedHeaders) {
            if (buffer.length() > 0) buffer +=';';
            buffer +=header.toLowerCase();
        }

        return buffer;
    }
    
    /**
     * Computes the canonical headers with values for the request. For AWS4, all
     * headers must be included in the signing process.
     */
    public static String getCanonicalizedHeaderString(Map<String, String> headers) {
        if ( headers == null || headers.isEmpty() ) {
            return '';
        }
        
        // step1: sort the headers by case-insensitive order
        List<String> sortedHeaders = new List<String>();
        sortedHeaders.addAll(headers.keySet());
        sortedHeaders.sort();

        /* step2: form the canonical header:value entries in sorted order. 
          * Multiple white spaces in the values should be compressed to a single space.
        */
        String buffer = '';
        for (String key : sortedHeaders) {
            buffer +=key.toLowerCase().replaceAll('\\s+', ' ' ) + ':' +
                headers.get(key).replaceAll('\\s+', ' ');
            buffer +='\n';
        }

        return buffer;
    }
    
    /**
     * Returns the canonical request string to go into the signer process; this 
     * consists of several canonical sub-parts.
    */
    public static String getCanonicalRequest(
            URL endpoint, 
            String httpMethod,
            String queryParameters, 
            String canonicalizedHeaderNames,
            String canonicalizedHeaders, 
            String bodyHash,
            String serviceName
    ) {
           if (serviceName.Equals('sqs')) {
           bodyHash=hash('');
        }
            String canonicalRequest =
            httpMethod + '\n' + getCanonicalizedResourcePath(endpoint) + '\n' +
            queryParameters + '\n' + canonicalizedHeaders + '\n' +
            canonicalizedHeaderNames + '\n' + bodyHash;

            return canonicalRequest;
    }

    /**
     * Returns the canonicalized resource path for the service endpoint.
    */
    public static String getCanonicalizedResourcePath(URL endpoint) {
        if ( endpoint == null ) {
            return '/';
        }
        
        String path = endpoint.getPath();
        if ( path == null || path=='') {
            return '/';
        }
        
        String encodedPath = urlEncode(path, true);
        if (encodedPath.startsWith('/')) {
            return encodedPath;
        } else {
            return '/'+encodedPath;
        }
    }
    
    /**
     * Examines the specified query string parameters and returns a
     * canonicalized form.
     * The canonicalized query string is formed by first sorting all the query
     * string parameters, then URI encoding both the key and value and then
     * joining them, in order, separating key value pairs with an '&'.
     *
     * @param parameters - The query string parameters to be canonicalized.
     * @return - A canonicalized form for the specified query string parameters.
     */
    public static String getCanonicalizedQueryString(Map<String, String> parameters) {
        if (parameters == null || parameters.isEmpty()) {
            return '';
        }
        map<String, String> sorted = new map<String, String>();
        list<String> mapkey=new list<String>();
        mapkey.addAll(parameters.keyset());
        Iterator<String> mapkeyIterator = mapkey.iterator();
        
       while (mapkeyIterator.hasNext()) {
            String key = mapkeyIterator.next();
            String value = parameters.get(key);
            sorted.put(URLEncode(key, false),URLEncode(value, false));
        }
        
        String builder = '';
        list<String> sortedmapkey =new list<string>();
        sortedmapkey.addAll(sorted.keyset());
        sortedmapkey.sort();
        Iterator<String> sortmapkeyIterator = sortedmapkey.iterator();
        
        while (sortmapkeyIterator.hasNext()) {
        String key=sortmapkeyIterator.next();
        builder += key;
        builder += '=';
        builder += sorted.get(key);
        if (sortmapkeyIterator.hasNext()) {
        builder +='&';
        }
        }
        return builder;
    }
    /**
     * Computes String to Sign
     */
    public static String getStringToSign(
            String signingScheme,
            String signingAlgorithm,
            String signingDateTime,
            String signingScope,
            String signingCanonicalRequest
    ) {
        String stringToSign =
        signingScheme + '-' + signingAlgorithm + '\n' +
        signingDateTime + '\n' +
        signingScope + '\n' +
        hash(signingCanonicalRequest);
        return stringToSign;
        
    }
    /**
     * Hashes the string using the SHA-256 algorithm.
     */
    public static blob sign(String stringData, blob key, String algorithm2) {
        try {
        Blob input = Blob.valueOf(stringData); 
        Blob mac = Crypto.generateMac(algorithm2,input,key);
        return mac;
        } 
        catch (Exception e) {
        system.debug('Unable to calculate a request signature: ' + e + e.getMessage());
        return null;
        }
    }
    /**
     * Encode the given URL
     */
     public static String URLEncode(String url, boolean keepPathSlash) {
        String encoded;
        try {
        encoded = EncodingUtil.urlEncode(url, 'UTF-8');
        } 
        catch (Exception e) {
        system.debug('UTF-8 encoding is not supported : '+ e +e.getMessage());
        return null;
        }
        if ( keepPathSlash) {
        encoded = encoded.replace('%2F', '/');
        }
        return encoded;
    }
    /**
     * Generate Digest of given string using the SHA-256 algorithm.
     */
    public static String hash(String data) {
        try {
        Blob myBlob = Blob.valueof(data);
        Blob hash =Crypto.generateDigest('SHA256', myBlob);
        String hexstring=EncodingUtil.convertToHex(hash);
        return hexstring;
        } 
        catch (Exception e) {
        system.debug('Unable to compute hash while signing request: ' + e + e.getMessage());
        return null;
        }
    }

}