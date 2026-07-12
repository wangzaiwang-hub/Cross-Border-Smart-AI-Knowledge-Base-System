package com.yuegang.zhihui.notification.application;
import com.yuegang.zhihui.notification.security.NotificationSecurity;import java.util.*;import javax.sql.DataSource;import org.springframework.beans.factory.annotation.Value;import org.springframework.context.annotation.*;
@Configuration(proxyBeanMethods=false)class NotificationConfiguration{
 @Bean NotificationService notificationService(DataSource dataSource){return new NotificationService(dataSource);}
 @Bean NotificationInboxService notificationInboxService(DataSource dataSource){return new NotificationInboxService(dataSource);}
 @Bean NotificationDispatchJob notificationDispatchJob(NotificationService service){return new NotificationDispatchJob(service);}
 @Bean NotificationQueryService notificationQueryService(DataSource dataSource){return new NotificationQueryService(dataSource);}
 @Bean NotificationSecurity notificationSecurity(@Value("${ygh.internal-request.hmac-base64}")String encoded){byte[]key=Base64.getDecoder().decode(encoded);try{return new NotificationSecurity(key);}finally{Arrays.fill(key,(byte)0);}}
}
