public with sharing class AmazonQueueHandler {
	
	 private static String make_sig(string canonicalBuffer, String secretKey) {        
        String macUrl ;
        if(secretKey != null && canonicalBuffer != null){
            String signingKey = EncodingUtil.base64Encode(Blob.valueOf(secretKey));
            Blob mac = Crypto.generateMac('HmacSHA256',blob.valueof(canonicalBuffer),blob.valueof(secretKey)); 
            macUrl = EncodingUtil.base64Encode(mac); 
        }
        return macUrl;
    }
  
    private static String getCurrentDate() {
        return DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }
    
    private static String encode(String message){
        return EncodingUtil.urlEncode(message,'UTF-8').replace('+', '%20').replace('*', '%2A').replace('%7E','~');
    }
    
    
    public static HttpResponse getHttpResponseBody(){
         String stringtosign;
         Date dtCurrentDate = Date.today();
         Datetime now = DateTime.now();
         Datetime expireson = now.AddHours(1);
         Long Lexpires = expireson.getTime()/1000;
         
         String currentDate= encode(getCurrentDate());
          
        Map<String,String> params = new Map<String,String>();
        params.put('Action','ReceiveMessage');
        params.put('AWSAccessKeyId',encode('AKIAIFL2OXRB25HQGQZA'));
        params.put('SignatureVersion','2');
        params.put('SignatureMethod','HmacSHA256');
        params.put('Timestamp',currentDate);
       
        //The string to sign has to be sorted by keys
        List<String> sortedKeys = new List<String>();
        sortedKeys.addAll(params.keySet());
        sortedKeys.sort();
 
        stringtosign = 'GET\n'+'sqs.us-east-1.amazonaws.com\n/'+'028825875979/'+'ens-crm-hir\n';
        
        Integer p = 0;
        for (String key : sortedKeys) {
            String value = params.get(key);
            if (p > 0) {
                stringtosign += '&';
            }
            p++;
            stringtosign += key+'='+value;
        } 
               
         //https://sqs.us-east-1.amazonaws.com  http://queue.amazonaws.com/
         String signed = make_sig(stringtosign,'PYYjfzdsd4hWiCfOgof3evhfQaih3NpVDyVIr8hf');
         String codedsigned = EncodingUtil.urlEncode(signed,'UTF-8');
        
         string sqsUrl = 'http://sqs.us-east-1.amazonaws.com/028825875979/ens-crm-hir?Action=ReceiveMessage' +
            '&AWSAccessKeyId=AKIAIFL2OXRB25HQGQZA'+
            '&Signature=' + codedsigned +
            '&SignatureVersion=2' +
            '&SignatureMethod=HmacSHA256'+
            '&Timestamp=' + currentDate;
            
         Http h = new Http();
         HttpRequest req = new HttpRequest();
         req.setEndpoint(sqsUrl);
         req.setMethod('GET'); // GET or POST
         
         system.debug('***req** '+req);
         
         HttpResponse res = new HttpResponse();
         res = h.send(req);
         
         system.debug('***res*** '+res);
         system.debug('***res*** '+res.getBody());
         return res;       
    } 

}