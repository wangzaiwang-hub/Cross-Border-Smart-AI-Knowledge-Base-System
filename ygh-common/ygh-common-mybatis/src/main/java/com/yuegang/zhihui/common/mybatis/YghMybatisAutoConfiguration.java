package com.yuegang.zhihui.common.mybatis;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import com.yuegang.zhihui.common.core.PageRequest;
import java.time.Clock;
import java.util.List;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.beans.factory.SmartInitializingSingleton;
import org.springframework.context.annotation.Bean;

/** Shared MyBatis-Plus auditing and bounded pagination infrastructure. */
@AutoConfiguration
public class YghMybatisAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public Clock auditClock() {
        return Clock.systemUTC();
    }

    @Bean
    @ConditionalOnMissingBean(MetaObjectHandler.class)
    public AuditMetaObjectHandler auditMetaObjectHandler(
            AuditorProvider auditorProvider,
            Clock auditClock
    ) {
        return new AuditMetaObjectHandler(auditorProvider, auditClock);
    }

    @Bean
    @ConditionalOnMissingBean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        var pagination = new PaginationInnerInterceptor();
        pagination.setMaxLimit((long) PageRequest.MAX_PAGE_SIZE);
        pagination.setOverflow(false);

        var interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(pagination);
        return interceptor;
    }

    @Bean
    public SmartInitializingSingleton mybatisPaginationGuard(
            List<MybatisPlusInterceptor> interceptors
    ) {
        return () -> {
            if (interceptors.size() != 1) {
                throw new IllegalStateException("exactly one MybatisPlusInterceptor is required");
            }
            var paginationInterceptors = interceptors.getFirst().getInterceptors().stream()
                    .filter(PaginationInnerInterceptor.class::isInstance)
                    .map(PaginationInnerInterceptor.class::cast)
                    .toList();
            boolean boundedPagination = paginationInterceptors.size() == 1
                    && paginationInterceptors.getFirst().getMaxLimit() != null
                    && paginationInterceptors.getFirst().getMaxLimit() >= 1
                    && paginationInterceptors.getFirst().getMaxLimit()
                            <= PageRequest.MAX_PAGE_SIZE
                    && !paginationInterceptors.getFirst().isOverflow();
            if (!boundedPagination) {
                throw new IllegalStateException(
                        "MybatisPlusInterceptor must include pagination limited to "
                                + PageRequest.MAX_PAGE_SIZE);
            }
        };
    }
}
