package com.yuegang.zhihui.ai.api;import java.time.OffsetDateTime;public record MessageView(String id,String role,String content,boolean refused,OffsetDateTime createdAt){}
