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
export const listAdminOrders = async (status?: string): Promise<Order[]> =>
    apiData(
        await useHttp().get("/api/v1/admin/orders", {
            params: { status: status || undefined, limit: 100 },
        }),
    );
export const listRoles = async (): Promise<Role[]> =>
    apiData(await useHttp().get("/api/v1/system/admin/roles"));
export const listPermissions = async (): Promise<Permission[]> =>
    apiData(await useHttp().get("/api/v1/system/admin/permissions"));
