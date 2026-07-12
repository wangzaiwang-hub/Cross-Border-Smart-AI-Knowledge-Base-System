package com.yuegang.zhihui.notification.api;
import com.yuegang.zhihui.common.core.ApiResponse;import com.yuegang.zhihui.common.web.TraceIdResolver;import com.yuegang.zhihui.notification.application.*;import com.yuegang.zhihui.notification.security.NotificationSecurity;import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import java.util.*;import org.springframework.web.bind.annotation.*;
@RestController public final class NotificationController{
 private final NotificationService service;private final NotificationInboxService inbox;private final NotificationSecurity security;
 public NotificationController(NotificationService service,NotificationInboxService inbox,NotificationSecurity security){this.service=service;this.inbox=inbox;this.security=security;}
 @PostMapping("/internal/v1/notifications") ApiResponse<NotificationView>create(@Valid @RequestBody NotificationCommand command,HttpServletRequest request){security.service(request);return ok(service.create(command),request);}
 @GetMapping("/api/v1/notifications") ApiResponse<List<NotificationView>>list(HttpServletRequest request){return ok(service.list(security.user(request)),request);}
 @GetMapping("/api/v1/notifications/unread-count") ApiResponse<Map<String,Long>>unread(HttpServletRequest request){return ok(Map.of("count",inbox.unreadCount(security.user(request))),request);}
 @PutMapping("/api/v1/notifications/{id}/read") ApiResponse<Map<String,Boolean>>read(@PathVariable String id,HttpServletRequest request){service.read(security.user(request),id);return ok(Map.of("completed",true),request);}
 @PutMapping("/api/v1/notifications/read-all") ApiResponse<Map<String,Integer>>readAll(HttpServletRequest request){return ok(Map.of("updated",inbox.readAll(security.user(request))),request);}
 private static<T>ApiResponse<T>ok(T data,HttpServletRequest request){return ApiResponse.success(data,TraceIdResolver.resolve(request));}
}
