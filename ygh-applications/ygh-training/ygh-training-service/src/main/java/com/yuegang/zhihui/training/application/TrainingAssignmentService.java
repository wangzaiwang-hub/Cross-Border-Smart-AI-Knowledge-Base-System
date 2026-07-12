package com.yuegang.zhihui.training.application;

import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import com.yuegang.zhihui.training.api.AssignmentView;
import com.yuegang.zhihui.training.api.CreateAssignmentRequest;
import com.yuegang.zhihui.training.api.TrainingStatisticsView;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;

public final class TrainingAssignmentService {
    private final JdbcTemplate jdbc;

    public TrainingAssignmentService(DataSource dataSource) { this.jdbc = new JdbcTemplate(dataSource); }

    public AssignmentView assign(long operatorId, CreateAssignmentRequest request) {
        long id = System.currentTimeMillis() * 1000 + Math.floorMod((request.userId() + request.courseId()).hashCode(), 1000);
        Long pathId = request.pathId() == null || request.pathId().isBlank() ? null : positive(request.pathId());
        jdbc.update("INSERT INTO training_assignment(id,user_id,path_id,course_id,assigned_by,due_at) SELECT ?,?,?,?,?,? WHERE EXISTS(SELECT 1 FROM training_course WHERE id=? AND status='PUBLISHED')", id, positive(request.userId()), pathId, positive(request.courseId()), operatorId, request.dueAt() == null ? null : Timestamp.from(request.dueAt().toInstant()), positive(request.courseId()));
        return find(id);
    }

    public List<AssignmentView> mine(long userId) {
        return jdbc.query("SELECT id,user_id,course_id,status,due_at FROM training_assignment WHERE user_id=? ORDER BY assigned_at DESC", (rs, row) -> map(rs), userId);
    }

    public TrainingStatisticsView statistics() {
        return jdbc.query("SELECT COUNT(*) assigned,SUM(status='IN_PROGRESS') progressing,SUM(status='COMPLETED') completed,SUM(status<>'COMPLETED' AND due_at<NOW(6)) overdue FROM training_assignment", rs -> {
            if (!rs.next()) return new TrainingStatisticsView(0,0,0,0,BigDecimal.ZERO);
            long assigned=rs.getLong("assigned"), completed=rs.getLong("completed");
            BigDecimal rate=assigned==0?BigDecimal.ZERO:BigDecimal.valueOf(completed*100).divide(BigDecimal.valueOf(assigned),2,RoundingMode.HALF_UP);
            return new TrainingStatisticsView(assigned,rs.getLong("progressing"),completed,rs.getLong("overdue"),rate);
        });
    }

    private AssignmentView find(long id) {
        return jdbc.query("SELECT id,user_id,course_id,status,due_at FROM training_assignment WHERE id=?", rs -> { if(!rs.next()) throw new BusinessException(ErrorCode.BUSINESS_CONFLICT); return map(rs); }, id);
    }

    private static AssignmentView map(java.sql.ResultSet rs) throws java.sql.SQLException {
        Timestamp due=rs.getTimestamp("due_at");
        OffsetDateTime dueAt=due==null?null:due.toInstant().atOffset(ZoneOffset.UTC);
        return new AssignmentView(Long.toString(rs.getLong("id")),Long.toString(rs.getLong("user_id")),Long.toString(rs.getLong("course_id")),rs.getString("status"),dueAt);
    }

    private static long positive(String value) {
        try { long id=Long.parseLong(value); if(id<=0) throw new NumberFormatException(); return id; }
        catch(NumberFormatException e){throw new BusinessException(ErrorCode.VALIDATION_ERROR);}
    }
}
