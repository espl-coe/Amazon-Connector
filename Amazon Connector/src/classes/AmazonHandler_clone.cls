public with sharing class AmazonHandler_clone {
private static final string CLASS_NAME = 'AmazonHandler';
    private static final string Method_NAME = 'getInfo';  
    /**
     * Method to create signature of amazon file
     * Argument: StringToSignByte and secret key of amazon account.
     * Return: Base64 encoded signature required to access file. 
     */
    private static String make_sig(string canonicalBuffer, String secretKey) {        
        String macUrl ;
        if(secretKey != null && canonicalBuffer != null){
            String signingKey = EncodingUtil.base64Encode(Blob.valueOf(secretKey));
            Blob mac = Crypto.generateMac('HMacSHA1', blob.valueof(canonicalBuffer),blob.valueof(secretKey)); 
            macUrl = EncodingUtil.base64Encode(mac); 
        }             
        return macUrl;
    }
    /**
     * Method to do common call out for GET and PUT method.
     * Argument: Credential record,fileName to read and mode of call out
     * Return: Return response object to its caller method.
     */
    private static HttpResponse getHttpResponseBody(Credentials__c credInst, String fileName, String mode,String endPointUrl){
    	 PresignedUrlSample S3url=new PresignedUrlSample(); 
         String url=S3url.getPresignedUrlToS3Object(credInst.Token__c,endPointUrl,fileName,label.Region_Name,mode,credInst.Credentials__c,'s3');
         Http h = new Http();
         HttpRequest req = new HttpRequest();
          system.debug('------url-----'+url);
         req.setEndpoint(url);
         req.setMethod(mode); // GET or POST
         HttpResponse res = new HttpResponse();
         res = h.send(req);
          system.debug('------res111-----'+res);
         /*
         if(!Test.isRunningTest()){
              res = h.send(req);
         }
         else {
              if(!url.contains('test')){
                   res.setHeader('Content-Type', 'application/json');
                   res.setBody('{"TranscriptCreditTypeID":1000,"AttemptedHours":3.0,"GPAHours":3.0}');
                   res.setStatusCode(200);
              }
              else{
                   res.setHeader('Content-Type', 'text/xml');
                   res.setBody('<?xml version="1.0" encoding="UTF-8"?><Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message><RequestId>06F3712510FA6773</RequestId></Error>');
                   res.setStatusCode(400);
             }
         }*/
         return res;       
    } 
    /**
     * Method to do httpcallout to Amazon S3 server to get information stored in object file.
     * After successfull/Failed callout, it updates event object with status and fetched content from Amazon file object.
     * Arugment : List of EventBean Object and Map of Id and System.
     * 
     */
    public static void getInfo(List<EventBean> newEventBeanList,Map<id,Credentials__c> sysCredentialMap){
        List<Event__c> updateEventList = new List<Event__c>();
        Map<String,String> errorMap;
        for(EventBean newEventBeanInst : newEventBeanList){
                Event__c newEventInst = newEventBeanInst.eventObj;
                Credentials__c credInst = sysCredentialMap.get(newEventInst.SourceSystem__c );
                errorMap = new Map<String,String>();
                if(credInst != null && credInst.Credentials__c != null ){                    
                    try{
                        String fileName ='';
                        String urlInfo = newEventBeanInst.link;
                        if(urlInfo != null && urlInfo != ''){
                             Integer i = urlInfo.lastIndexOf('/');
                             fileName = urlInfo.subString(i+1,urlInfo.length());
                             filename = EncodingUtil.urlEncode(filename, 'UTF-8');
                             urlInfo = urlInfo.subString(0,i+1);
                        }
                        HttpResponse res = getHttpResponseBody(credInst,filename,'GET',urlInfo);
                        system.debug('------res-----'+res);
                        if(res != null && res.getBody() != null){
                              newEventInst.ContentJSON__c  = res.getBody();
                              system.debug('------res.getBody()-------'+res.getBody());
                        }
                        if(res.getStatusCode() != 200){
                        	system.debug('------status-------');
                             newEventInst.EventStateID__c = Label.Error_State;
                             XmlStreamReader xsrBody = new XmlStreamReader(res.getBody());
                             errorMap = parseResponseBody(xsrBody);   
                             String errorMessage = getJsonErrorMessage(errorMap.get(Label.Error_Code),errorMap.get(Label.Error_Reason),CLASS_NAME,Method_NAME,errorMap.get(Label.Error_Context));                          
                             newEventInst.FailureReason__c = errorMessage;
                             newEventInst.ContentJSON__c  = '';  
                        }
                    }
                    catch(CalloutException ex){
                         newEventInst.EventStateID__c = Label.Error_State;
                         if(newEventInst.FailureReason__c == null || newEventInst.FailureReason__c == ''){
                             newEventInst.ContentJSON__c  = ex.getMessage();
                             String errorMessage = getJsonErrorMessage(ex.getMessage(),Label.Callout_Error,
                             CLASS_NAME,Method_NAME,Label.Amazon_Callout_Error);
                             newEventInst.FailureReason__c = errorMessage != null ? errorMessage : '';
                             newEventInst.ContentJSON__c  = '';
                         }
                    }
                     updateEventList.add(newEventInst);
                }  
                else{
                     newEventInst.ContentJSON__c  = '';
                     newEventInst.EventStateID__c = Label.Error_State;
                     String errorMessage = getJsonErrorMessage('',Label.Credential_Not_Available,CLASS_NAME,Method_NAME,Label.Amazon_Retrieval_Error);
                     newEventInst.FailureReason__c = errorMessage != null ? errorMessage : '';
                     newEventInst.ContentJSON__c  = ''; 
                     updateEventList.add(newEventInst);
                }     
        }
        try{
             Database.SaveResult[] updateResults = Database.update(updateEventList,false);
             system.debug('------updateResults-------'+updateResults);
             List<Event__c> copyUpdateEventList = new List<Event__c>();
             
             for(Integer i=0; i<updateResults.size(); i++){
                 if (!updateResults.get(i).isSuccess()){
                     // DML operation failed
                     errorMap = new Map<String,String>();
                     Database.Error error = updateResults.get(i).getErrors().get(0);
                     String failedDML = error.getMessage();
                     failedDML = failedDML.subString(0,100);
                     Event__c eInst = updateEventList.get(i);//failed record from the list
                         
                     eInst.EventStateID__c = Label.Error_State;
                     eInst.ContentJSON__c  = '';
                     String errorMessage = getJsonErrorMessage(String.valueOf(error.getStatusCode()),label.Amazon_DML_Exception,CLASS_NAME,Method_NAME,label.Amazon_Failed_DML_Error);
                     eInst.FailureReason__c  = errorMessage != null ? errorMessage : '';
                    
                     copyUpdateEventList.add(eInst);
                 }
             }
             if(copyUpdateEventList.size()>0){
                  Database.SaveResult[] srList1 = Database.update(copyUpdateEventList,false);
             }
        }
        catch(Exception e){} 
    }
    private static Map<String,String> parseResponseBody(XmlStreamReader reader) {
        Map<String,String> errorMap= new Map<String,String>();
        boolean isNextXmlElementNull = false;   
        try{    
            while(!isNextXmlElementNull) {
                // Start at the beginning of the book and make sure that it is a book
                if (reader.getEventType() == XmlTag.START_ELEMENT) {
                    if ('Code' == reader.getLocalName()) {
                        errorMap.put(Label.Error_Code,parseValue(reader));
                    }
                    if('Message' == reader.getLocalName()){
                        errorMap.put(Label.Error_Reason,parseValue(reader));
                    }
                }
                if (reader.hasNext()) {
                    reader.next();
                } else {
                    isNextXmlElementNull = true;
                    break;
                }
            }
            errorMap.put(Label.Error_Context,Label.Amazon_Retrieval_Callout_Error);
        }
        catch(Exception ex){
             errorMap.put(Label.Error_Code,ex.getTypeName());
             errorMap.put(Label.Error_Reason,ex.getMessage());
             errorMap.put(Label.Error_Context,Label.Amazon_Parsing_Error);
        }
        return errorMap;
    }
    private static String parseValue(XmlStreamReader reader) {
        String val = '';
        boolean isSafeToGetNextXmlElement = true;
        while(isSafeToGetNextXmlElement) {
            if (reader.getEventType() == XmlTag.END_ELEMENT) {
                break;
            } else if (reader.getEventType() == XmlTag.CHARACTERS) {
                val = reader.getText();
            }          
            if (reader.hasNext()) {
                reader.next();
            } else {
                isSafeToGetNextXmlElement = false;
                break;
            }
        }
        return val;
    }
    
    /*
      ***Return Json format Error Message = {"Error Code" :"" ,"Error Reason":"Reason for Failure" ,
                              "Error Context":[{"ClassName":"TestClass"},{"Method":"TestMethod"},{"Context":""}]}   
    */
    private static String getJsonErrorMessage(String errorCode, String errorReason, String errorClassName, 
                                                               String errorMethodName, String context){
        
        String jsonErrorMessage =  '{\n'+ '\"'+Label.Error_Code +'\" ' + ':' + '\"'+ errorCode +'\" , \n' +
                                        '\"'+Label.Error_Reason +'\"' + ':'+  '\"'+ errorReason +'\" ,\n' +
                                        '\"'+Label.Error_Context +'\"'  + ':'+ '{"ClassName":'+'\"'+ errorClassName+'\"'+','+
                                                                            '"Method":'+'\"'+errorMethodName+'\"'+',' +
                                                                             '"Context":'+'\"'+context+'\"'+'}' +'\n}';
        return jsonErrorMessage;                         
    }
}