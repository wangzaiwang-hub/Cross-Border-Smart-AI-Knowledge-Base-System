package com.yuegang.zhihui.user.application;

import com.yuegang.zhihui.user.domain.UserProfileRepository;
import com.yuegang.zhihui.user.infrastructure.JdbcUserProfileRepository;
import javax.sql.DataSource;
import org.springframework.context.annotation.*;

@Configuration(proxyBeanMethods = false)
class UserProfileConfiguration {
    @Bean UserProfileRepository userProfileRepository(DataSource dataSource) { return new JdbcUserProfileRepository(dataSource); }
    @Bean UserProfileService userProfileService(UserProfileRepository repository) { return new UserProfileService(repository); }
}
