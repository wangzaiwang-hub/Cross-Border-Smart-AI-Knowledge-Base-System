package com.yuegang.zhihui.knowledge.application;

import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import com.yuegang.zhihui.knowledge.api.KnowledgeIndexJobView;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;

public final class KnowledgeIndexJobService {
    private final JdbcTemplate jdbc;

    public KnowledgeIndexJobService(DataSource dataSource) {
        this.jdbc = new JdbcTemplate(dataSource);
    }

    public List<KnowledgeIndexJobView> list(String documentId, String status, int limit) {
        StringBuilder sql = new StringBuilder("SELECT id,document_id,index_version,job_type,status,retry_count,last_error,updated_at FROM knowledge_index_job WHERE 1=1");
        var arguments = new java.util.ArrayList<>();
        if (documentId != null && !documentId.isBlank()) {
            sql.append(" AND document_id=?");
            arguments.add(positive(documentId));
        }
        if (status != null && !status.isBlank()) {
            sql.append(" AND status=?");
            arguments.add(status.strip().toUpperCase(java.util.Locale.ROOT));
        }
        sql.append(" ORDER BY updated_at DESC LIMIT ?");
        arguments.add(Math.max(1, Math.min(limit, 100)));
        return jdbc.query(sql.toString(), (row, number) -> view(
                row.getLong(1), row.getLong(2), row.getString(3), row.getString(4),
                row.getString(5), row.getInt(6), row.getString(7), row.getTimestamp(8)),
                arguments.toArray());
    }

    public KnowledgeIndexJobView retry(String id) {
        long jobId = positive(id);
        int updated = jdbc.update("UPDATE knowledge_index_job SET status='RETRY',retry_count=0,next_retry_at=NOW(6),last_error=NULL WHERE id=? AND status='FAILED'", jobId);
        if (updated != 1) {
            throw new BusinessException(ErrorCode.BUSINESS_CONFLICT);
        }
        return jdbc.query("SELECT id,document_id,index_version,job_type,status,retry_count,last_error,updated_at FROM knowledge_index_job WHERE id=?",
                result -> {
                    if (!result.next()) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
                    return view(result.getLong(1), result.getLong(2), result.getString(3), result.getString(4),
                            result.getString(5), result.getInt(6), result.getString(7), result.getTimestamp(8));
                }, jobId);
    }

    private static KnowledgeIndexJobView view(long id, long documentId, String version, String type,
                                               String status, int retries, String failure, Timestamp updatedAt) {
        int progress = switch (status) {
            case "SUCCEEDED" -> 100;
            case "PROCESSING" -> 75;
            case "PENDING", "RETRY" -> 50;
            default -> 0;
        };
        OffsetDateTime time = updatedAt.toInstant().atOffset(ZoneOffset.UTC);
        return new KnowledgeIndexJobView(Long.toString(id), Long.toString(documentId), version, type,
                status, progress, retries, failure, time);
    }

    private static long positive(String value) {
        try {
            long parsed = Long.parseLong(value);
            if (parsed <= 0) throw new NumberFormatException();
            return parsed;
        } catch (RuntimeException failure) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }
    }
}
