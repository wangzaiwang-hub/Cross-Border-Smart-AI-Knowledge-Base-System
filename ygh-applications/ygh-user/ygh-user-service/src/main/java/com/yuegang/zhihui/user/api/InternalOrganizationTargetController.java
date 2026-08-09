package com.yuegang.zhihui.user.api;

import com.yuegang.zhihui.common.core.ApiResponse;
import com.yuegang.zhihui.common.core.BusinessException;
import com.yuegang.zhihui.common.core.ErrorCode;
import com.yuegang.zhihui.common.web.TraceIdResolver;
import com.yuegang.zhihui.user.security.UserInternalServiceVerifier;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/internal/v1/organization")
public final class InternalOrganizationTargetController {
    private final JdbcTemplate jdbc;
    private final UserInternalServiceVerifier verifier;

    public InternalOrganizationTargetController(DataSource dataSource, UserInternalServiceVerifier verifier) {
        jdbc = new JdbcTemplate(dataSource);
        this.verifier = verifier;
    }

    @GetMapping("/targets")
    ApiResponse<List<String>> targets(@RequestParam String type, @RequestParam String id, HttpServletRequest request) {
        verifier.verify(request);
        long target = positive(id);
        List<String> users = switch (type) {
            case "DEPARTMENT" -> jdbc.queryForList("""
                    SELECT CAST(user_id AS CHAR)
                    FROM user_employee
                    WHERE department_id=? AND employment_status='ACTIVE'
                    """, String.class, target);
            case "POSITION" -> jdbc.queryForList("""
                    SELECT CAST(e.user_id AS CHAR)
                    FROM user_employee e
                    JOIN user_employee_position ep ON ep.employee_id=e.id
                    WHERE ep.position_id=? AND e.employment_status='ACTIVE'
                    """, String.class, target);
            case "EMPLOYEE" -> jdbc.queryForList("""
                    SELECT CAST(user_id AS CHAR)
                    FROM user_employee
                    WHERE (id=? OR user_id=?) AND employment_status='ACTIVE'
                    """, String.class, target, target);
            default -> throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        };
        return ApiResponse.success(users, TraceIdResolver.resolve(request));
    }

    private static long positive(String value) {
        try {
            long id = Long.parseLong(value);
            if (id <= 0) {
                throw new NumberFormatException();
            }
            return id;
        } catch (Exception exception) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR);
        }
    }
}
