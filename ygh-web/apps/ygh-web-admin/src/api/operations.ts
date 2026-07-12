import { apiData } from "@ygh/web-shared";
import { useHttp } from "./client";
export interface Dashboard {
    summary: {
        totalServices: number;
        healthyServices: number;
        unavailableServices: number;
    };
    services: Array<{ service: string; status: string; latencyMs: number }>;
    pending: Array<{ type: string; count: number; source: string }>;
    generatedAt: string;
}
export interface AdminAccount {
    accountId: string;
    userId: string;
    principal: string;
    accountType: string;
    status: string;
    failedLoginCount: number;
    lockedUntil?: string;
    lastLoginAt?: string;
    version: number;
    createdAt: string;
}
export interface Department {
    id: string;
    parentId?: string;
    code: string;
    name: string;
    sortOrder: number;
    enabled: boolean;
    version: number;
}
export interface Position {
    id: string;
    code: string;
    name: string;
    description?: string;
    enabled: boolean;
    version: number;
}
export interface Employee {
    id: string;
    userId: string;
    employeeNo: string;
    departmentId?: string;
    positionIds: string[];
    status: string;
    hiredOn?: string;
    version: number;
}
export interface Product {
    spuId: string;
    skuId: string;
    categoryId: string;
    brandId: string;
    name: string;
    skuCode: string;
    price: string;
    currency: string;
    status: string;
    traceabilityCode: string;
    version: number;
    images?: string[];
    specifications?: Record<string, string>;
}
export interface ProductCategory {
    id: string;
    code: string;
    name: string;
    enabled: boolean;
}
export interface ProductBrand {
    id: string;
    code: string;
    name: string;
    enabled: boolean;
}
export interface ProductBatch {
    id: string;
    skuId: string;
    batchNo: string;
    origin?: string;
    proofUrl?: string;
    producedOn?: string;
    expiresOn?: string;
    traceDescription?: string;
}
export interface Order {
    orderId: string;
    orderNo: string;
    userId: string;
    status: string;
    totalAmount: string;
    currency: string;
    version: number;
    createdAt: string;
}
export interface Role {
    id: string;
    code: string;
    name: string;
    enabled: boolean;
    version: number;
    permissions: string[];
}
export interface Permission {
    id: string;
    code: string;
    name: string;
    resourceType: string;
    enabled: boolean;
}
export interface AuthoritySnapshot {
    userId: string;
    roles: string[];
    permissions: string[];
    version: number;
}
export interface KnowledgeDocument {
    id: string;
    title: string;
    category: string;
    fileName: string;
    mediaType: string;
    sizeBytes: number;
    status: string;
    version: number;
    updatedAt: string;
}
export interface KnowledgeJob {
    id: string;
    documentId: string;
    taskType?: string;
    indexVersion?: string;
    jobType?: string;
    status: string;
    progress: number;
    retryCount: number;
    failureReason?: string;
    updatedAt: string;
}
export interface DeadLetter {
    id: string;
    messageId: string;
    eventId: string;
    failureReason: string;
    failedAt: string;
}
export interface PromptConfig {
    id: string;
    code: string;
    systemPrompt: string;
    modelName: string;
    temperature: number;
    knowledgeScope: string;
    sensitiveWords: string;
    enabled: boolean;
    version: number;
    updatedAt: string;
}
export interface EvaluationCase {
    id: string;
    category: string;
    question: string;
    expectedEvidence: string;
    forbiddenAnswer?: string;
    enabled: boolean;
}
export interface AiSummary {
    conversations: number;
    messages: number;
    refusals: number;
    feedback: number;
    helpfulFeedback: number;
    enabledEvaluationCases: number;
    activePrompt: boolean;
}
export interface EvaluationRun {
    runId: string;
    caseId: string;
    passed: boolean;
    score: number;
    citationCount: number;
    durationMs: number;
    failureReason?: string;
}
export interface TrainingAnalytics {
    assigned: number;
    completed: number;
    overdue: number;
    completionRate: string;
    averageScore: string;
    weakKnowledge: Array<{ knowledgeCode: string; wrongCount: number }>;
}
export interface TrainingCourse {
    id: string;
    title: string;
    description: string;
    status: string;
    passScore: number;
    estimatedMinutes: number;
    version: number;
}
export interface TrainingChapter {
    id: string;
    courseId: string;
    title: string;
    sequenceNo: number;
    minimumActiveSeconds: number;
    version: number;
}
export interface TrainingGate {
    id: string;
    chapterId: string;
    title: string;
    passScore: number;
    maximumAttempts: number;
}
export interface AuditLog {
    timestamp: string;
    userId?: string;
    module: string;
    action: string;
    result: string;
    status: number;
    traceId: string;
    message: string;
}
export interface SystemSetting {
    key: string;
    value: string;
    valueType: string;
    secret: boolean;
    version: number;
}
export interface Dictionary {
    code: string;
    name: string;
    items: Array<{ key: string; value: string; sortOrder: number }>;
}
export interface DictionaryAdmin {
    code: string;
    name: string;
    enabled: boolean;
    version: number;
    items: Array<{
        key: string;
        value: string;
        sortOrder: number;
        enabled: boolean;
        version: number;
    }>;
}
export interface FeatureFlag {
    key: string;
    enabled: boolean;
    rolloutPercent: number;
    rulesJson: string;
    version: number;
}
export interface Inventory {
    skuId: string;
    available: number;
    locked: number;
    sold: number;
    version: number;
}
export interface WalletTransaction {
    transactionId: string;
    userId: string;
    type: string;
    status: string;
    amount: string;
    currency: string;
    referenceId: string;
    createdAt: string;
}
export const getDashboard = async (): Promise<Dashboard> =>
    apiData(await useHttp().get("/api/v1/admin/dashboard"));
export const listAccounts = async (
    keyword?: string,
    status?: string,
): Promise<AdminAccount[]> =>
    apiData(
        await useHttp().get("/api/v1/auth/admin/users", {
            params: {
                keyword: keyword || undefined,
                status: status || undefined,
                limit: 100,
            },
        }),
    );
export const listDepartments = async (): Promise<Department[]> =>
    apiData(await useHttp().get("/api/v1/user/organization/departments"));
export const createDepartment = async (command: {
    parentId?: string;
    code: string;
    name: string;
    sortOrder: number;
}): Promise<Department> =>
    apiData(
        await useHttp().post("/api/v1/user/organization/departments", command),
    );
export const listPositions = async (): Promise<Position[]> =>
    apiData(await useHttp().get("/api/v1/user/organization/positions"));
export const createPosition = async (command: {
    code: string;
    name: string;
    description?: string;
}): Promise<Position> =>
    apiData(
        await useHttp().post("/api/v1/user/organization/positions", command),
    );
export const listEmployees = async (): Promise<Employee[]> =>
    apiData(await useHttp().get("/api/v1/user/organization/employees"));
export const createEmployee = async (command: {
    userId: string;
    employeeNo: string;
    departmentId?: string;
    positionIds: string[];
    hiredOn?: string;
}): Promise<Employee> =>
    apiData(
        await useHttp().post("/api/v1/user/organization/employees", command),
    );
export const replaceEmployeePositions = async (
    employeeId: string,
    positionIds: string[],
): Promise<Employee> =>
    apiData(
        await useHttp().put(
            `/api/v1/user/organization/employees/${employeeId}/positions`,
            positionIds,
        ),
    );
export const changeEmployeeStatus = async (
    employeeId: string,
    status: "ACTIVE" | "SUSPENDED" | "LEFT",
): Promise<Employee> =>
    apiData(
        await useHttp().put(
            `/api/v1/user/organization/employees/${employeeId}/status/${status}`,
        ),
    );
export const listAdminProducts = async (
    keyword?: string,
    status?: string,
): Promise<Product[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/products", {
            params: {
                keyword: keyword || undefined,
                status: status || undefined,
                limit: 100,
            },
        }),
    );
export const listProductCategories = async (): Promise<ProductCategory[]> =>
    apiData(await useHttp().get("/api/v1/product-categories"));
export const listProductBrands = async (): Promise<ProductBrand[]> =>
    apiData(await useHttp().get("/api/v1/product-brands"));
export const createProductCategory = async (command: {
    parentId?: string;
    code: string;
    name: string;
    sortOrder: number;
}): Promise<ProductCategory> =>
    apiData(await useHttp().post("/api/v1/admin/product-categories", command));
export const createProductBrand = async (command: {
    code: string;
    name: string;
    logoUrl?: string;
}): Promise<ProductBrand> =>
    apiData(await useHttp().post("/api/v1/admin/product-brands", command));
export async function createProduct(command: {
    categoryId: string;
    brandId?: string;
    name: string;
    skuCode: string;
    price: string;
    currency: string;
    images: string[];
    traceabilityCode?: string;
    version: number;
    specifications: Record<string, string>;
}): Promise<Product> {
    return apiData(await useHttp().post("/api/v1/admin/products", command));
}
export async function updateProduct(
    product: Product,
    command: {
        categoryId: string;
        brandId?: string;
        name: string;
        description?: string;
        price: string;
        currency: string;
        images: string[];
        traceabilityCode?: string;
        specifications: Record<string, string>;
    },
): Promise<Product> {
    return apiData(
        await useHttp().put(`/api/v1/admin/products/${product.skuId}`, {
            ...command,
            version: product.version,
        }),
    );
}
export const createProductBatch = async (
    skuId: string,
    command: {
        batchNo: string;
        origin?: string;
        proofUrl?: string;
        producedOn?: string;
        expiresOn?: string;
        traceDescription?: string;
    },
): Promise<ProductBatch> =>
    apiData(
        await useHttp().post(
            `/api/v1/admin/products/${skuId}/batches`,
            command,
        ),
    );
export const createProductTraceEvent = async (
    skuId: string,
    command: {
        type: string;
        location?: string;
        occurredAt: string;
        details: Record<string, unknown>;
    },
): Promise<void> => {
    await useHttp().post(
        `/api/v1/admin/products/${skuId}/trace-events`,
        command,
    );
};
export const listAdminOrders = async (status?: string): Promise<Order[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/orders", {
            params: { status: status || undefined, limit: 100 },
        }),
    );
export async function changeAccountStatus(
    account: AdminAccount,
    status: "ACTIVE" | "DISABLED",
    reason: string,
): Promise<void> {
    await useHttp().put(`/api/v1/auth/admin/users/${account.userId}/status`, {
        status,
        version: account.version,
        reason,
    });
}
export async function changeProductStatus(
    product: Product,
    status: "DRAFT" | "PUBLISHED" | "OFF_SHELF",
): Promise<Product> {
    return apiData(
        await useHttp().put(
            `/api/v1/admin/products/${product.skuId}/status`,
            undefined,
            { params: { status, version: product.version } },
        ),
    );
}
export const listRoles = async (): Promise<Role[]> =>
    apiData(await useHttp().get("/api/v1/system/admin/roles"));
export const listPermissions = async (): Promise<Permission[]> =>
    apiData(await useHttp().get("/api/v1/system/admin/permissions"));
export const getUserAuthorities = async (
    userId: string,
): Promise<AuthoritySnapshot> =>
    apiData(await useHttp().get(`/api/v1/system/users/${userId}/authorities`));
export const assignUserRoles = async (
    snapshot: AuthoritySnapshot,
    roleCodes: string[],
    reason: string,
): Promise<AuthoritySnapshot> =>
    apiData(
        await useHttp().put(`/api/v1/system/users/${snapshot.userId}/roles`, {
            roleCodes,
            version: snapshot.version,
            reason,
        }),
    );
export async function saveRole(role: Role): Promise<Role> {
    return apiData(
        await useHttp().put(`/api/v1/system/admin/roles/${role.code}`, {
            code: role.code,
            name: role.name,
            permissions: role.permissions,
            enabled: role.enabled,
            version: role.version,
        }),
    );
}
export async function savePermission(
    permission: Permission,
): Promise<Permission> {
    return apiData(
        await useHttp().put(
            `/api/v1/system/admin/permissions/${permission.code}`,
            {
                code: permission.code,
                name: permission.name,
                resourceType: permission.resourceType,
                enabled: permission.enabled,
            },
        ),
    );
}
export const listAdminKnowledge = async (
    status?: string,
): Promise<KnowledgeDocument[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/knowledge/documents", {
            params: { status: status || undefined, limit: 100 },
        }),
    );
export async function uploadKnowledge(
    title: string,
    category: string,
    file: File,
): Promise<KnowledgeDocument> {
    const body = new FormData();
    body.append("title", title);
    body.append("category", category);
    body.append("file", file);
    return apiData(await useHttp().post("/api/v1/knowledge/documents", body));
}
export async function reviewKnowledge(
    document: KnowledgeDocument,
    decision: "APPROVE" | "REJECT",
    comment: string,
): Promise<KnowledgeDocument> {
    return apiData(
        await useHttp().post(
            `/api/v1/knowledge/documents/${document.id}/review`,
            { decision, comment, version: document.version },
        ),
    );
}
export async function offlineKnowledge(
    document: KnowledgeDocument,
    reason: string,
): Promise<KnowledgeDocument> {
    return apiData(
        await useHttp().put(
            `/api/v1/admin/knowledge/documents/${document.id}/offline`,
            undefined,
            { params: { version: document.version, reason } },
        ),
    );
}
export const listProcessingJobs = async (
    status?: string,
): Promise<KnowledgeJob[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/knowledge/processing-jobs", {
            params: { status: status || undefined, limit: 100 },
        }),
    );
export const listIndexJobs = async (status?: string): Promise<KnowledgeJob[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/knowledge/index-jobs", {
            params: { status: status || undefined, limit: 100 },
        }),
    );
export const retryProcessingJob = async (id: string): Promise<void> => {
    await useHttp().post(`/api/v1/admin/knowledge/processing-jobs/${id}/retry`);
};
export const retryIndexJob = async (id: string): Promise<void> => {
    await useHttp().post(`/api/v1/admin/knowledge/index-jobs/${id}/retry`);
};
export const listDeadLetters = async (): Promise<DeadLetter[]> =>
    apiData(await useHttp().get("/api/v1/admin/notifications/dead-letters"));
export const replayDeadLetter = async (id: string): Promise<void> => {
    await useHttp().post(
        `/api/v1/admin/notifications/dead-letters/${id}/replay`,
    );
};
export const dispatchNotifications = async (): Promise<number> => {
    const result = apiData<{ sent: number }>(
        await useHttp().post("/api/v1/admin/notifications/dispatch"),
    );
    return result.sent;
};
export const listPrompts = async (): Promise<PromptConfig[]> =>
    apiData(await useHttp().get("/api/v1/admin/ai/prompts"));
export const createPrompt = async (command: {
    code: string;
    systemPrompt: string;
    modelName: string;
    temperature: number;
    knowledgeScope: string;
    sensitiveWords: string;
    enabled: boolean;
    version: number;
}): Promise<PromptConfig> =>
    apiData(await useHttp().post("/api/v1/admin/ai/prompts", command));
export const listEvaluationCases = async (): Promise<EvaluationCase[]> =>
    apiData(await useHttp().get("/api/v1/admin/ai/evaluation-cases"));
export const createEvaluationCase = async (command: {
    category: string;
    question: string;
    expectedEvidence: string;
    forbiddenAnswer?: string;
    enabled: boolean;
}): Promise<EvaluationCase> =>
    apiData(await useHttp().post("/api/v1/admin/ai/evaluation-cases", command));
export const getAiSummary = async (): Promise<AiSummary> =>
    apiData(await useHttp().get("/api/v1/admin/ai/summary"));
export const runAiEvaluations = async (): Promise<EvaluationRun[]> =>
    apiData(await useHttp().post("/api/v1/admin/ai/evaluations/run"));
export const getTrainingAnalytics = async (): Promise<TrainingAnalytics> =>
    apiData(await useHttp().get("/api/v1/training/learning/admin/analytics"));
export const listTrainingCourses = async (): Promise<TrainingCourse[]> =>
    apiData(await useHttp().get("/api/v1/training/courses"));
export const listTrainingChapters = async (
    courseId: string,
): Promise<TrainingChapter[]> =>
    apiData(
        await useHttp().get(`/api/v1/training/courses/${courseId}/chapters`),
    );
export const listTrainingGates = async (
    chapterId: string,
): Promise<TrainingGate[]> =>
    apiData(
        await useHttp().get(`/api/v1/training/chapters/${chapterId}/gates`),
    );
export const createTrainingCourse = async (command: {
    title: string;
    description: string;
    estimatedMinutes: number;
    passScore: number;
}): Promise<TrainingCourse> =>
    apiData(await useHttp().post("/api/v1/training/admin/courses", command));
export const createTrainingChapter = async (command: {
    courseId: string;
    title: string;
    sequenceNo: number;
    minimumActiveSeconds: number;
}): Promise<TrainingChapter> =>
    apiData(await useHttp().post("/api/v1/training/admin/chapters", command));
export const createTrainingGate = async (command: {
    chapterId: string;
    title: string;
    passScore: number;
    maximumAttempts: number;
}): Promise<TrainingGate> =>
    apiData(await useHttp().post("/api/v1/training/admin/gates", command));
export const createTrainingQuestion = async (command: {
    gateId: string;
    type: string;
    stem: string;
    options: string[];
    correctAnswer: string;
    explanation: string;
    score: number;
}): Promise<void> => {
    await useHttp().post("/api/v1/training/admin/questions", command);
};
export const uploadTrainingDocument = async (
    chapterId: string,
    file: File,
): Promise<void> => {
    const body = new FormData();
    body.append("file", file);
    await useHttp().post(
        `/api/v1/training/admin/chapters/${chapterId}/documents`,
        body,
    );
};
export const publishTrainingCourse = async (
    course: TrainingCourse,
): Promise<TrainingCourse> =>
    apiData(
        await useHttp().put(
            `/api/v1/training/admin/courses/${course.id}/publish`,
            undefined,
            { params: { version: course.version } },
        ),
    );
export async function createScopedTrainingAssignment(command: {
    targetType: "DEPARTMENT" | "POSITION" | "EMPLOYEE";
    targetId: string;
    pathId?: string;
    courseId: string;
    dueAt?: string;
}): Promise<void> {
    await useHttp().post("/api/v1/training/assignments/scoped", command);
}
export const listAuditLogs = async (
    params: Record<string, string | number | undefined> = {},
): Promise<AuditLog[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/audit-logs", {
            params: { ...params, limit: 100 },
        }),
    );
export const listSystemSettings = async (): Promise<SystemSetting[]> =>
    apiData(await useHttp().get("/api/v1/system/settings"));
export const saveSystemSetting = async (
    setting: SystemSetting,
    value: string,
): Promise<SystemSetting> =>
    apiData(
        await useHttp().put(`/api/v1/system/settings/${setting.key}`, {
            value,
            valueType: setting.valueType,
            secret: setting.secret,
            version: setting.version,
        }),
    );
export const listDictionaries = async (): Promise<Dictionary[]> =>
    apiData(await useHttp().get("/api/v1/system/dictionaries"));
export const listAdminDictionaries = async (): Promise<DictionaryAdmin[]> =>
    apiData(await useHttp().get("/api/v1/system/dictionaries/admin"));
export const saveDictionary = async (command: {
    code: string;
    name: string;
    enabled: boolean;
    version: number;
}): Promise<DictionaryAdmin> =>
    apiData(
        await useHttp().put(
            `/api/v1/system/dictionaries/admin/${command.code}`,
            command,
        ),
    );
export const saveDictionaryItem = async (
    dictionaryCode: string,
    command: {
        key: string;
        value: string;
        sortOrder: number;
        enabled: boolean;
        version: number;
    },
): Promise<DictionaryAdmin> =>
    apiData(
        await useHttp().put(
            `/api/v1/system/dictionaries/admin/${dictionaryCode}/items/${command.key}`,
            command,
        ),
    );
export const listFeatureFlags = async (): Promise<FeatureFlag[]> =>
    apiData(await useHttp().get("/api/v1/system/feature-flags"));
export async function saveFeatureFlag(flag: FeatureFlag): Promise<FeatureFlag> {
    return apiData(
        await useHttp().put(`/api/v1/system/feature-flags/${flag.key}`, {
            enabled: flag.enabled,
            rolloutPercent: flag.rolloutPercent,
            rulesJson: flag.rulesJson,
            version: flag.version,
        }),
    );
}
export const listAdminInventory = async (): Promise<Inventory[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/inventory", {
            params: { limit: 500 },
        }),
    );
export const listWalletTransactions = async (): Promise<WalletTransaction[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/wallet/transactions", {
            params: { limit: 500 },
        }),
    );
