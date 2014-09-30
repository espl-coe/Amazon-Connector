public with sharing class AmazonHandler_1 {
    private static final string CLASS_NAME = 'AmazonHandler';
    private static final string Method_NAME = 'getInfo';
    private static final string STR_CONTENT = 'Content';
    private static final string Event_Method_NAME = 'createNewEvents';
    private static final string PUT = 'PUT';
    
    /**
     * Method to do common call out for GET and PUT method.
     * Argument: Credential record,fileName to read and mode of call out
     * Return: Return response object to its caller method.
     */
     
     
    public void callout()
    {
    	
    	getHttpResponseBody('AKIAITEBA3ZFLDTQYV2A','hir/W2014-09-05 18:37:18.0E460T4.json','GET','http://ens.campusops.net.s3.amazonaws.com/','eiHYHUw7Vo4ZBAH1JQ/gLuSKUegg9F1ZE5Lc65tn','s3',null);
    }
   
   
    public static HttpResponse getHttpResponseBody(String accesskey, String fileName, String mode,String endPointUrl,String secretKey,String service,String content){

         PresignedUrl S3url=new PresignedUrl(); 
         String url=S3url.getPresignedUrlToS3Object(accesskey,endPointUrl,fileName,label.Region_Name,mode,secretKey,service);
         Http h = new Http();
         HttpRequest req = new HttpRequest();
         req.setEndpoint(url);
         if (String.isNotBlank(content) && mode.equals(PUT)) {
            req.setBodyAsBlob(Blob.valueOf(content));
         }
         req.setMethod(mode); // GET or POST
         HttpResponse res = new HttpResponse();
         //res = h.send(req);
         if(!Test.isRunningTest()){
              res = h.send(req);
              system.debug('------res111-----'+res);
              system.debug('------res------'+res.getBody());
         }
         else {
              if(!url.contains('test')){
                   res.setHeader('Content-Type', 'application/json');
                   res.setBody('{"Topic": [{ "10": "Acc1.json"},{"12": "Acc2.json"}]}');
                   res.setStatusCode(200);
              }
              else{
                   res.setHeader('Content-Type', 'text/xml');
                   res.setBody('<?xml version="1.0" encoding="UTF-8"?><Error><Code>Signature does not match</Code><Message>The signature that we were calculated does not match with your signature.Please check the access key or signing method.</Message><RequestId>06F3712510FA6773</RequestId></Error>');
                   res.setStatusCode(400);
             }
         }
         
         if(res.getStatusCode()==200)
         system.debug('------Success-----'+res.getBody());
         else
         system.debug('------Failure-----'+res);
         return res;
    } 
   }