package com.yuegang.zhihui.ai.infrastructure;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.yuegang.zhihui.ai.domain.ModelGateway;
import com.yuegang.zhihui.ai.domain.ModelProviderException;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/** 豆包 Responses API 适配器。API Key 仅保存在服务端配置中，不进入日志或前端响应。 */
public final class DoubaoModelGateway implements ModelGateway {
    private static final ObjectMapper JSON = new ObjectMapper();
    private final RestClient client;
    private final String modelName;
    private final String responsesUrl;
    public DoubaoModelGateway(String baseUrl,String apiKey,String modelName){
        if(apiKey==null||apiKey.isBlank())throw new IllegalStateException("Doubao key missing");
        this.modelName=modelName;
        responsesUrl=trimTrailingSlash(baseUrl)+"/responses";
        client=RestClient.builder()
                .defaultHeader(HttpHeaders.AUTHORIZATION,"Bearer "+apiKey)
                .build();
    }
    @Override public String answer(String system,String user){
        Map<?,?> response;
        try {
            response=client.post().uri(responsesUrl)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("model",modelName,"instructions",system,"input",user))
                    .retrieve().body(Map.class);
        } catch (RestClientResponseException exception) {
            throw providerFailure(exception);
        }
        String text=extractText(response);
        if(text==null||text.isBlank())throw new IllegalStateException("empty model response");
        return text;
    }
    @Override public String modelName(){return modelName;}

    private static String trimTrailingSlash(String value){
        if(value==null||value.isBlank())throw new IllegalArgumentException("Doubao base URL missing");
        return value.endsWith("/")?value.substring(0,value.length()-1):value;
    }

    private static String extractText(Map<?,?> response){
        if(response==null)return null;
        Object direct=response.get("output_text");
        if(direct instanceof String text&&!text.isBlank())return text;
        Object output=response.get("output");
        if(!(output instanceof List<?> items))return null;
        StringBuilder result=new StringBuilder();
        for(Object item:items){
            if(!(item instanceof Map<?,?> itemMap))continue;
            appendText(result,itemMap);
            Object content=itemMap.get("content");
            if(content instanceof List<?> parts){
                for(Object part:parts)if(part instanceof Map<?,?> partMap)appendText(result,partMap);
            }
        }
        return result.isEmpty()?null:result.toString();
    }

    private static void appendText(StringBuilder result,Map<?,?> value){
        Object type=value.get("type");
        Object text=value.get("text");
        if(text instanceof String content&&!content.isBlank()
                &&("output_text".equals(type)||"text".equals(type))){
            if(!result.isEmpty())result.append('\n');
            result.append(content);
        }
    }

    private static ModelProviderException providerFailure(RestClientResponseException exception){
        String code="UNKNOWN";
        String message="未返回错误说明";
        try {
            JsonNode body=JSON.readTree(exception.getResponseBodyAsString());
            JsonNode error=body.path("error");
            if(error.isMissingNode()||error.isNull())error=body;
            code=error.path("code").asText(code);
            message=error.path("message").asText(message);
        } catch (Exception ignored) {
            // 非 JSON 错误页也只透传 HTTP 状态，不记录响应正文。
        }
        return new ModelProviderException(exception.getStatusCode().value(),code,message,exception);
    }
}
