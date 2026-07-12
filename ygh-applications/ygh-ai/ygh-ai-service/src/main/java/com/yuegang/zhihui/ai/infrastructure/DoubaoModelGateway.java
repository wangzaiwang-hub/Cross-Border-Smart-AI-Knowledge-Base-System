package com.yuegang.zhihui.ai.infrastructure;
import com.yuegang.zhihui.ai.domain.ModelGateway;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.openai.OpenAiChatModel;
import java.time.Duration;

/** 豆包 OpenAI-compatible endpoint adapter implemented through LangChain4j. */
public final class DoubaoModelGateway implements ModelGateway {
    private final ChatModel model;
    public DoubaoModelGateway(String baseUrl,String apiKey,String modelName){
        if(apiKey==null||apiKey.isBlank())throw new IllegalStateException("Doubao key missing");
        model=OpenAiChatModel.builder().baseUrl(baseUrl).apiKey(apiKey).modelName(modelName)
                .temperature(0.2).timeout(Duration.ofSeconds(60)).maxRetries(1)
                .logRequests(false).logResponses(false).build();
    }
    @Override public String answer(String system,String user){
        var request=ChatRequest.builder().messages(SystemMessage.from(system),UserMessage.from(user)).build();
        var response=model.chat(request);
        if(response==null||response.aiMessage()==null||response.aiMessage().text()==null)
            throw new IllegalStateException("empty model response");
        return response.aiMessage().text();
    }
}
