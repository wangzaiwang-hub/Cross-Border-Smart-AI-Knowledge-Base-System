package com.yuegang.zhihui.user.infrastructure;

import com.yuegang.zhihui.user.api.*;
import com.yuegang.zhihui.user.domain.UserProfileRepository;
import java.sql.*;
import java.util.*;
import javax.sql.DataSource;

public final class JdbcUserProfileRepository implements UserProfileRepository {
    private final DataSource dataSource;
    public JdbcUserProfileRepository(DataSource dataSource) { this.dataSource = Objects.requireNonNull(dataSource); }
    public Optional<UserProfileView> findByUserId(long userId) {
        try (var c = dataSource.getConnection(); var s = c.prepareStatement(
                "SELECT user_id,display_name,avatar_url,version FROM user_profile WHERE user_id=?")) {
            s.setLong(1, userId);
            try (var rows = s.executeQuery()) { return read(rows); }
        } catch (SQLException failure) { throw new IllegalStateException("user profile cannot be read", failure); }
    }
    public Optional<UserProfileView> save(long userId, UpdateUserProfileRequest request) {
        try (var c = dataSource.getConnection()) {
            c.setAutoCommit(false);
            try {
                Long current = lockVersion(c, userId);
                if (current == null) {
                    if (request.version() != 0) { c.rollback(); return Optional.empty(); }
                    try (var s = c.prepareStatement("""
                            INSERT INTO user_profile(user_id,display_name,avatar_url,locale,timezone,profile_completed,version)
                            VALUES (?,?,?,?,?,TRUE,0)
                            """)) { bind(s, userId, request); s.executeUpdate(); }
                } else {
                    if (current != request.version()) { c.rollback(); return Optional.empty(); }
                    try (var s = c.prepareStatement("""
                            UPDATE user_profile SET display_name=?,avatar_url=?,locale=?,timezone=?,
                                profile_completed=TRUE,version=version+1 WHERE user_id=? AND version=?
                            """)) {
                        s.setString(1, request.displayName().trim()); s.setString(2, blankToNull(request.avatarUrl()));
                        s.setString(3, request.locale()); s.setString(4, request.timezone());
                        s.setLong(5, userId); s.setLong(6, current);
                        if (s.executeUpdate() != 1) { c.rollback(); return Optional.empty(); }
                    }
                }
                c.commit();
            } catch (SQLException failure) { c.rollback(); throw failure; }
            finally { c.setAutoCommit(true); }
        } catch (SQLException failure) { throw new IllegalStateException("user profile cannot be saved", failure); }
        return findByUserId(userId);
    }
    private static Long lockVersion(Connection c, long userId) throws SQLException {
        try (var s = c.prepareStatement("SELECT version FROM user_profile WHERE user_id=? FOR UPDATE")) {
            s.setLong(1, userId); try (var rows = s.executeQuery()) { return rows.next() ? rows.getLong(1) : null; }
        }
    }
    private static void bind(PreparedStatement s, long userId, UpdateUserProfileRequest r) throws SQLException {
        s.setLong(1, userId); s.setString(2, r.displayName().trim()); s.setString(3, blankToNull(r.avatarUrl()));
        s.setString(4, r.locale()); s.setString(5, r.timezone());
    }
    private static Optional<UserProfileView> read(ResultSet rows) throws SQLException {
        if (!rows.next()) return Optional.empty();
        return Optional.of(new UserProfileView(Long.toString(rows.getLong("user_id")),
                rows.getString("display_name"), rows.getString("avatar_url"), rows.getLong("version")));
    }
    private static String blankToNull(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
