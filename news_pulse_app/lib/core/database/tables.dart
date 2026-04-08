// ============================================================
// 테이블명 및 컬럼명 상수 정의
// SQL 쿼리에서 하드코딩을 방지하고 오타를 줄이기 위해 사용한다
// ============================================================

class Tables {
  // 기존 테이블명
  static const String processedItems = 'processed_items';
  static const String hotNews = 'hot_news';
  static const String subscribers = 'subscribers';
  static const String runHistory = 'run_history';
  static const String errorLog = 'error_log';
  static const String filterConfig = 'filter_config';
  static const String healthCheckResults = 'health_check_results';

  // 신규 테이블명 (마이그레이션으로 추가됨)
  static const String whitelistKeywords = 'whitelist_keywords';
  static const String modelUsageLog = 'model_usage_log';
  static const String promptVersions = 'prompt_versions';
  static const String scheduleLog = 'schedule_log';
}

class ProcessedItemsCol {
  static const String id = 'id';
  static const String urlHash = 'url_hash';
  static const String url = 'url';
  static const String title = 'title';
  static const String source = 'source';
  static const String language = 'language';
  static const String rawContent = 'raw_content';
  static const String summaryKo = 'summary_ko';
  static const String tags = 'tags';
  static const String upvotes = 'upvotes';
  static const String isHot = 'is_hot';
  static const String pipelinePath = 'pipeline_path';
  static const String processingTimeMs = 'processing_time_ms';
  static const String telegramSent = 'telegram_sent';
  static const String createdAt = 'created_at';
  // 신규 컬럼 (F03 읽음 상태, F04 모델 추적)
  static const String isRead = 'is_read';
  static const String summarizerModel = 'summarizer_model';
  static const String translatorModel = 'translator_model';
  static const String promptVersionId = 'prompt_version_id';
}

class WhitelistKeywordsCol {
  static const String id = 'id';
  static const String keyword = 'keyword';
  static const String createdAt = 'created_at';
}

class ModelUsageLogCol {
  static const String id = 'id';
  static const String runId = 'run_id';
  static const String processedItemId = 'processed_item_id';
  static const String modelName = 'model_name';
  static const String taskType = 'task_type';
  static const String latencyMs = 'latency_ms';
  static const String inputTokens = 'input_tokens';
  static const String success = 'success';
  static const String createdAt = 'created_at';
}

class PromptVersionsCol {
  static const String id = 'id';
  static const String promptType = 'prompt_type';
  static const String version = 'version';
  static const String content = 'content';
  static const String isActive = 'is_active';
  static const String createdAt = 'created_at';
}

class ScheduleLogCol {
  static const String id = 'id';
  static const String scheduledAt = 'scheduled_at';
  static const String actualAt = 'actual_at';
  static const String status = 'status';
  static const String createdAt = 'created_at';
}

class HotNewsCol {
  static const String id = 'id';
  static const String processedItemId = 'processed_item_id';
  static const String url = 'url';
  static const String title = 'title';
  static const String source = 'source';
  static const String summaryKo = 'summary_ko';
  static const String tags = 'tags';
  static const String upvotes = 'upvotes';
  static const String hotReason = 'hot_reason';
  static const String createdAt = 'created_at';
}

class SubscribersCol {
  static const String id = 'id';
  static const String chatId = 'chat_id';
  static const String username = 'username';
  static const String firstName = 'first_name';
  static const String status = 'status';
  static const String requestedAt = 'requested_at';
  static const String approvedAt = 'approved_at';
  static const String rejectedAt = 'rejected_at';
  static const String isAdmin = 'is_admin';
}

class RunHistoryCol {
  static const String id = 'id';
  static const String startedAt = 'started_at';
  static const String finishedAt = 'finished_at';
  static const String status = 'status';
  static const String fetchedCount = 'fetched_count';
  static const String filteredCount = 'filtered_count';
  static const String summarizedCount = 'summarized_count';
  static const String sentCount = 'sent_count';
  static const String totalDurationMs = 'total_duration_ms';
  static const String modelLoadMs = 'model_load_ms';
  static const String inferenceMs = 'inference_ms';
  static const String memoryMode = 'memory_mode';
  static const String errorMessage = 'error_message';
}

class ErrorLogCol {
  static const String id = 'id';
  static const String runId = 'run_id';
  static const String severity = 'severity';
  static const String module = 'module';
  static const String message = 'message';
  static const String traceback = 'traceback';
  static const String createdAt = 'created_at';
}

class FilterConfigCol {
  static const String id = 'id';
  static const String key = 'key';
  static const String value = 'value';
  static const String description = 'description';
  static const String updatedAt = 'updated_at';
}

class HealthCheckResultsCol {
  static const String id = 'id';
  static const String checkType = 'check_type';
  static const String target = 'target';
  static const String status = 'status';
  static const String message = 'message';
  static const String responseTimeMs = 'response_time_ms';
  static const String createdAt = 'created_at';
}
