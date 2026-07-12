package com.yuegang.zhihui.search.api;import jakarta.validation.constraints.*;public record SearchRequest(@NotBlank @Size(max=500)String query,@Min(1)@Max(50)int limit,String category){}
