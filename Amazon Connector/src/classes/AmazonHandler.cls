/** 
 *  Description : Handler class to retrieve and upload file content to AmazonS3. 
 *
 *  Revision History:
 *
 *  Version          Author              Date                Description
 *  1.0              Vishal Prasad       27/06/2014          Initial Draft
 */
public with sharing class AmazonHandler {
    private static final string CLASS_NAME = 'AmazonHandler';
    private static final string Method_NAME = 'getInfo';  
    private static final string STR_CONTENT = 'Content';  
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
    private static HttpResponse getHttpResponseBody(Credentials__c credInst, String fileName,String folderName, String mode,String endPointUrl){
         String stringtosign;
         Date dtCurrentDate = Date.today();
         Datetime now = DateTime.now();
         Datetime expireson = now.AddHours(1);
         Long Lexpires = expireson.getTime()/1000;
         
         if(mode.equalsIgnoreCase('GET') && folderName != null && folderName != ''){
               stringtosign = 'GET\n\n\n'+Lexpires+'\n/'+credInst.BucketName__c+'/'+folderName+'/'+fileName;
         }
         else{
         	   stringtosign = 'GET\n\n\n'+Lexpires+'\n/'+credInst.BucketName__c+'/'+fileName;
         }
         
         String signed = make_sig(stringtosign,credInst.Credentials__c);
         String codedsigned = EncodingUtil.urlEncode(signed,'UTF-8');
         String url = endPointUrl +fileName+'?AWSAccessKeyId='+credInst.Token__c+'&Expires='+Lexpires+'&Signature='+codedsigned;
         
         Http h = new Http();
         HttpRequest req = new HttpRequest();
         req.setEndpoint(url);
         req.setMethod(mode); // GET or POST
         HttpResponse res = new HttpResponse();
         res = h.send(req);
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
                        String folderName ='';
                        String urlInfo = newEventBeanInst.link;
                        if(urlInfo != null && urlInfo != ''){
                        	
                             Integer i = urlInfo.lastIndexOf('/');
                             fileName = urlInfo.subString(i+1,urlInfo.length());
                             filename = EncodingUtil.urlEncode(filename, 'UTF-8');
                             
                             List<String> lstString = urlInfo.split('/');
                             if(lstString.size() > 4){
                                folderName = lstString[3];
                             } 
                             urlInfo = urlInfo.subString(0,i+1);
                        }
                        
                        HttpResponse res = getHttpResponseBody(credInst,filename,folderName,'GET',urlInfo);
                       
                        if(res != null && res.getBody() != null & res.getStatusCode() == 200){
                            
                              // Check if Json Data body contains "Content" Key
                              Map<String, Object> mapjsonKeyToObject = (Map<String, Object>)
                                                      JSON.deserializeUntyped(res.getBody());
							  if(mapjsonKeyToObject != null && mapjsonKeyToObject.containsKey(STR_CONTENT)){
                                    newEventInst.ContentJSON__c = JSON.serialize( mapjsonKeyToObject.get(STR_CONTENT));
							  }					   
							  else{
							  	    newEventInst.ContentJSON__c  = res.getBody();
							  }	 
                        }
                        if(res.getStatusCode() != 200){
                             newEventInst.EventStateID__c = Label.Error_State;
                             XmlStreamReader xsrBody = new XmlStreamReader(res.getBody());
                             errorMap = parseResponseBody(xsrBody); 
                             String errorMessage = getJsonErrorMessage(errorMap.get(Label.Error_Code),errorMap.get(Label.Error_Reason),CLASS_NAME,Method_NAME,errorMap.get(Label.Error_Context));                          
                             newEventInst.FailureReason__c = errorMessage;
                             newEventInst.ContentJSON__c  = ''; 
                             newEventInst.EventStateID__c = 'Error'; 
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
                    	
                    	String strCode = parseValue(reader);
                        errorMap.put(Label.Error_Code,strCode);
                    }
                    if('Message' == reader.getLocalName()){
                    	String strMessage = parseValue(reader);
                        errorMap.put(Label.Error_Reason,strMessage);
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