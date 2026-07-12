<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { Search } from "@element-plus/icons-vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
    changeAccountStatus,
    changeProductStatus,
    listAccounts,
    listAdminInventory,
    listAdminOrders,
    listAdminProducts,
    listWalletTransactions,
    type AdminAccount,
    type Product,
} from "@/api/operations";
type Row = Record<string, unknown>;
const route = useRoute();
const keyword = ref("");
const status = ref("");
const loading = ref(true);
const rows = ref<Row[]>([]);
const unsupported = ref("");
const configs: Record<
    string,
    { description: string; columns: Array<{ key: string; label: string }> }
> = {
    user: {
        description: "管理消费者账号和账号状态。",
        columns: [
            { key: "userId", label: "用户 ID" },
            { key: "principal", label: "登录账号" },
            { key: "accountType", label: "账号类型" },
            { key: "status", label: "状态" },
            { key: "failedLoginCount", label: "失败次数" },
            { key: "lastLoginAt", label: "最近登录" },
        ],
    },
    product: {
        description: "维护商品、价格、溯源与上下架。",
        columns: [
            { key: "skuCode", label: "SKU" },
            { key: "name", label: "商品名称" },
            { key: "categoryId", label: "类目 ID" },
            { key: "price", label: "售价" },
            { key: "currency", label: "币种" },
            { key: "status", label: "状态" },
        ],
    },
    order: {
        description: "查看订单状态机与模拟支付结果。",
        columns: [
            { key: "orderNo", label: "订单号" },
            { key: "userId", label: "用户 ID" },
            { key: "totalAmount", label: "金额" },
            { key: "currency", label: "币种" },
            { key: "status", label: "状态" },
            { key: "createdAt", label: "创建时间" },
        ],
    },
    inventory: {
        description:
            "查看库存领域服务公开的只读管理视图；调整仍必须形成库存业务流水。",
        columns: [
            { key: "skuId", label: "SKU ID" },
            { key: "available", label: "可用" },
            { key: "locked", label: "锁定" },
            { key: "sold", label: "已售" },
            { key: "version", label: "版本" },
        ],
    },
    wallet: {
        description: "审计虚拟充值、支付和退款流水；不接入任何真实支付渠道。",
        columns: [
            { key: "transactionId", label: "流水 ID" },
            { key: "userId", label: "用户 ID" },
            { key: "type", label: "类型" },
            { key: "amount", label: "金额" },
            { key: "status", label: "状态" },
            { key: "createdAt", label: "发生时间" },
        ],
    },
};
const entity = computed(() => String(route.meta.entity));
const config = computed(() => configs[entity.value] || configs.user!);
const visible = computed(() =>
    rows.value.filter((row) =>
        Object.values(row)
            .join(" ")
            .toLowerCase()
            .includes(keyword.value.toLowerCase()),
    ),
);
async function load() {
    loading.value = true;
    unsupported.value = "";
    try {
        if (entity.value === "user")
            rows.value = (await listAccounts(
                keyword.value,
                status.value,
            )) as unknown as Row[];
        else if (entity.value === "product")
            rows.value = (await listAdminProducts(
                keyword.value,
                status.value,
            )) as unknown as Row[];
        else if (entity.value === "order")
            rows.value = (await listAdminOrders(
                status.value,
            )) as unknown as Row[];
        else if (entity.value === "inventory")
            rows.value = (await listAdminInventory()) as unknown as Row[];
        else if (entity.value === "wallet")
            rows.value = (await listWalletTransactions()) as unknown as Row[];
        else {
            rows.value = [];
            unsupported.value = config.value.description;
        }
    } catch {
        ElMessage.error(`${String(route.meta.title)}加载失败`);
    } finally {
        loading.value = false;
    }
}
function format(value: unknown) {
    if (typeof value === "string" && /^\d{4}-\d\d-\d\dT/.test(value))
        return new Date(value).toLocaleString("zh-CN");
    return value ?? "--";
}
async function changeState(row: Row) {
    try {
        if (entity.value === "user") {
            const account = row as unknown as AdminAccount;
            const next = account.status === "ACTIVE" ? "DISABLED" : "ACTIVE";
            const { value } = await ElMessageBox.prompt(
                `确认将账号状态改为 ${next}？请输入原因`,
                "账号状态变更",
                {
                    inputValidator: (value) =>
                        Boolean(value?.trim()) || "原因不能为空",
                },
            );
            await changeAccountStatus(account, next, value);
        } else if (entity.value === "product") {
            const product = row as unknown as Product;
            const next =
                product.status === "PUBLISHED" ? "OFF_SHELF" : "PUBLISHED";
            await ElMessageBox.confirm(
                `确认将商品状态改为 ${next}？`,
                "商品状态变更",
            );
            await changeProductStatus(product, next);
        }
        ElMessage.success("状态已更新");
        await load();
    } catch (error) {
        if (error !== "cancel" && error !== "close")
            ElMessage.error("状态更新失败，版本可能已变化");
    }
}
watch(() => route.fullPath, load, { immediate: true });
</script>
<template>
    <div class="page-head">
        <div>
            <h1>{{ route.meta.title }}</h1>
            <p>{{ config.description }}</p>
        </div>
    </div>
    <div class="panel filter-row">
        <el-input
            v-model="keyword"
            :prefix-icon="Search"
            placeholder="输入关键字查询"
            clearable
            style="width: 280px"
            @keyup.enter="load"
        /><el-input
            v-model="status"
            placeholder="状态编码（可选）"
            clearable
            style="width: 180px"
        /><el-button type="primary" @click="load">查询</el-button
        ><el-button
            @click="
                keyword = '';
                status = '';
                load();
            "
            >重置</el-button
        >
    </div>
    <el-alert
        v-if="unsupported"
        :title="unsupported"
        description="为避免 Admin 跨库或绕过服务边界，页面不会用演示数据伪装此能力。需要先由对应领域服务提供经过权限控制的管理查询契约。"
        type="warning"
        :closable="false"
        style="margin-bottom: 14px"
    />
    <section v-loading="loading" class="panel table-panel">
        <el-table :data="visible" stripe empty-text="暂无真实数据"
            ><el-table-column
                v-for="col in config.columns"
                :key="col.key"
                :prop="col.key"
                :label="col.label"
                min-width="130"
                ><template #default="scope"
                    ><el-tag
                        v-if="col.key === 'status'"
                        size="small"
                        effect="plain"
                        >{{ format(scope.row[col.key]) }}</el-tag
                    ><span v-else>{{
                        format(scope.row[col.key])
                    }}</span></template
                ></el-table-column
            ><el-table-column
                v-if="['user', 'product'].includes(entity)"
                label="操作"
                width="130"
                ><template #default="scope"
                    ><el-button
                        link
                        type="primary"
                        @click="changeState(scope.row)"
                        >{{
                            entity === "user"
                                ? scope.row.status === "ACTIVE"
                                    ? "停用"
                                    : "启用"
                                : scope.row.status === "PUBLISHED"
                                  ? "下架"
                                  : "上架"
                        }}</el-button
                    ></template
                ></el-table-column
            ></el-table
        ><el-pagination
            background
            layout="total"
            :total="visible.length"
            style="margin-top: 16px; justify-content: flex-end"
        />
    </section>
</template>
