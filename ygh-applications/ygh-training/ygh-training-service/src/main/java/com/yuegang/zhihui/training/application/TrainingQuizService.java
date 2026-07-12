package com.yuegang.zhihui.training.application;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import com.yuegang.zhihui.training.api.QuizAttemptView;
import com.yuegang.zhihui.training.api.SubmitQuizRequest;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Locale;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

public final class TrainingQuizService {
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final ObjectMapper json;

    public TrainingQuizService(DataSource dataSource, ObjectMapper json) {
        this.jdbc = new JdbcTemplate(dataSource);
        this.tx = new TransactionTemplate(new DataSourceTransactionManager(dataSource));
        this.json = json;
    }

    public QuizAttemptView submit(long userId, SubmitQuizRequest request) {
        return tx.execute(status -> grade(userId, request));
    }

    private QuizAttemptView grade(long userId, SubmitQuizRequest request) {
        QuizAttemptView existing = jdbc.query("SELECT id,assignment_id,gate_id,score,passed FROM training_quiz_attempt WHERE request_id=? AND user_id=?", rs -> rs.next() ? view(rs) : null, request.requestId(), userId);
        if (existing != null) return existing;
        long assignmentId = positive(request.assignmentId());
        long gateId = positive(request.gateId());
        Integer allowed = jdbc.queryForObject("SELECT COUNT(*) FROM training_assignment a JOIN training_gate g JOIN training_chapter c ON c.id=g.chapter_id AND c.course_id=a.course_id WHERE a.id=? AND a.user_id=? AND g.id=? AND a.status IN ('ASSIGNED','IN_PROGRESS')", Integer.class, assignmentId, userId, gateId);
        if (allowed == null || allowed != 1) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        Integer maximum = jdbc.queryForObject("SELECT maximum_attempts FROM training_gate WHERE id=?", Integer.class, gateId);
        Integer attempts = jdbc.queryForObject("SELECT COUNT(*) FROM training_quiz_attempt WHERE assignment_id=? AND gate_id=?", Integer.class, assignmentId, gateId);
        if (maximum != null && attempts != null && attempts >= maximum) throw new BusinessException(ErrorCode.BUSINESS_CONFLICT);
        int[] total = {0};
        int[] earned = {0};
        jdbc.query("SELECT id,correct_answer_hash,score FROM training_question WHERE gate_id=?", rs -> {
            int value = rs.getInt("score");
            total[0] += value;
            String answer = request.answers().get(Long.toString(rs.getLong("id")));
            if (answer != null && hash(answer).equalsIgnoreCase(rs.getString("correct_answer_hash"))) earned[0] += value;
            else jdbc.update("INSERT INTO training_weakness(user_id,knowledge_code,wrong_count,last_wrong_at) VALUES(?,?,1,NOW(6)) ON DUPLICATE KEY UPDATE wrong_count=wrong_count+1,last_wrong_at=NOW(6)", userId, "QUESTION:" + rs.getLong("id"));
        }, gateId);
        if (total[0] == 0) throw new BusinessException(ErrorCode.BUSINESS_CONFLICT);
        int score = Math.round(earned[0] * 100f / total[0]);
        int passScore = jdbc.queryForObject("SELECT pass_score FROM training_gate WHERE id=?", Integer.class, gateId);
        boolean passed = score >= passScore;
        long id = System.currentTimeMillis() * 1000 + Math.floorMod(request.requestId().hashCode(), 1000);
        jdbc.update("INSERT INTO training_quiz_attempt(id,request_id,assignment_id,gate_id,user_id,score,passed,answers_json,started_at) VALUES(?,?,?,?,?,?,?,?,?)", id, request.requestId(), assignmentId, gateId, userId, score, passed, answersJson(request), LocalDateTime.now());
        return new QuizAttemptView(Long.toString(id), Long.toString(assignmentId), Long.toString(gateId), score, passed);
    }

    private static QuizAttemptView view(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new QuizAttemptView(Long.toString(rs.getLong("id")), Long.toString(rs.getLong("assignment_id")), Long.toString(rs.getLong("gate_id")), rs.getInt("score"), rs.getBoolean("passed"));
    }

    private String answersJson(SubmitQuizRequest request) {
        try { return json.writeValueAsString(request.answers()); }
        catch (JsonProcessingException e) { throw new BusinessException(ErrorCode.VALIDATION_ERROR); }
    }

    private static String hash(String answer) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(answer.strip().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8))); }
        catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private static long positive(String value) {
        try { long id = Long.parseLong(value); if (id <= 0) throw new NumberFormatException(); return id; }
        catch (NumberFormatException e) { throw new BusinessException(ErrorCode.VALIDATION_ERROR); }
    }
}
