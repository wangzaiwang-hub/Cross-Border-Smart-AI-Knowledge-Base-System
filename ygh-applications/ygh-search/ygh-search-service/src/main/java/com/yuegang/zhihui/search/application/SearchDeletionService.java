package com.yuegang.zhihui.search.application;

import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import com.yuegang.zhihui.search.infrastructure.ElasticsearchRestClientFactory;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.client.RestClient;

public final class SearchDeletionService {
    private final JdbcTemplate jdbc;
    private final RestClient elastic;
    private final String alias;

    public SearchDeletionService(JdbcTemplate jdbc, String baseUrl, String alias) {
        this(jdbc, baseUrl, "", "", alias);
    }

    public SearchDeletionService(JdbcTemplate jdbc, String baseUrl, String username, String password, String alias) {
        this.jdbc = jdbc;
        this.elastic = ElasticsearchRestClientFactory.create(baseUrl, username, password);
        this.alias = alias;
    }

    public void deleteDocument(String document) {
        long id;
        try {
            id = Long.parseLong(document);
            if (id <= 0) throw new NumberFormatException();
        } catch (Exception failure) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }
        jdbc.update("DELETE FROM search_embedding WHERE document_id=?", id);
        elastic.post().uri("/" + alias + "/_delete_by_query?conflicts=proceed&refresh=true")
                .body(Map.of("query", Map.of("term", Map.of("documentId", document))))
                .retrieve().toBodilessEntity();
    }
}
