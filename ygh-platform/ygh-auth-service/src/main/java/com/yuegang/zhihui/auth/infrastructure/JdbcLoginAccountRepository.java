package com.yuegang.zhihui.auth.infrastructure;

import com.yuegang.zhihui.auth.domain.*;
import java.sql.SQLException;
import java.util.Objects;
import java.util.Optional;
import javax.sql.DataSource;

public final class JdbcLoginAccountRepository implements LoginAccountRepository {
    private static final String FIND_SQL = """
            SELECT a.id, a.user_id, a.account_type, a.status,
                   c.password_hash, c.password_algorithm, c.password_version
            FROM auth_account a
            JOIN auth_credential c ON c.account_id = a.id
            WHERE a.principal = ?
            """;
    private final DataSource dataSource;

    public JdbcLoginAccountRepository(DataSource dataSource) {
        this.dataSource = Objects.requireNonNull(dataSource, "dataSource must not be null");
    }

    @Override
    public Optional<LoginAccount> findByPrincipal(String normalizedPrincipal) {
        String principal = PrincipalNormalizer.normalize(normalizedPrincipal);
        try (var connection = dataSource.getConnection();
                var statement = connection.prepareStatement(FIND_SQL)) {
            statement.setString(1, principal);
            try (var rows = statement.executeQuery()) {
                if (!rows.next()) return Optional.empty();
                return Optional.of(new LoginAccount(
                        rows.getLong("id"),
                        rows.getLong("user_id"),
                        rows.getString("account_type"),
                        AccountStatus.valueOf(rows.getString("status")),
                        new PasswordDigest(
                                rows.getString("password_hash"),
                                rows.getString("password_algorithm"),
                                rows.getInt("password_version"))));
            }
        } catch (SQLException | IllegalArgumentException failure) {
            throw new AccountSecurityPersistenceException("login account cannot be read", failure);
        }
    }
}
