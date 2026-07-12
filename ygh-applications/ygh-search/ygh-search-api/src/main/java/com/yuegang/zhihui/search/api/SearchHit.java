package com.yuegang.zhihui.search.api;public record SearchHit(String documentId,String chunkId,String title,String excerpt,double lexicalScore,double vectorScore,double finalScore){}
