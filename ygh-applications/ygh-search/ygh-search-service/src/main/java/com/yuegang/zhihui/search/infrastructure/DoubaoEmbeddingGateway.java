package com.yuegang.zhihui.search.infrastructure;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

/** 豆包 OpenAI-compatible embedding adapter implemented through LangChain4j. */
public final class DoubaoEmbeddingGateway {
    private final EmbeddingModel model;
    public DoubaoEmbeddingGateway(String baseUrl,String apiKey,String modelName){
        if(apiKey==null||apiKey.isBlank())throw new IllegalStateException("Doubao embedding key missing");
        model=OpenAiEmbeddingModel.builder().baseUrl(baseUrl).apiKey(apiKey).modelName(modelName)
                .timeout(Duration.ofSeconds(60)).maxRetries(1).logRequests(false).logResponses(false).build();
    }
    public List<Double> embed(String text){
        float[] vector=model.embed(text).content().vector();
        List<Double> result=new ArrayList<>(vector.length);
        for(float value:vector)result.add((double)value);
        return List.copyOf(result);
    }
}
