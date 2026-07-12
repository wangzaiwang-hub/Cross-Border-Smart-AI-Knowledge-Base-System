import {
    createRouter,
    createWebHistory,
    type RouteRecordRaw,
} from "vue-router";
import { useSessionStore } from "@ygh/web-shared";
import PublicLayout from "@/layouts/PublicLayout.vue";
import WorkspaceLayout from "@/layouts/WorkspaceLayout.vue";

const routes: RouteRecordRaw[] = [
    {
        path: "/login",
        component: () => import("@/views/auth/LoginView.vue"),
        meta: { guest: true },
    },
    {
        path: "/register",
        component: () => import("@/views/auth/RegisterView.vue"),
        meta: { guest: true },
    },
    {
        path: "/password-reset",
        component: () => import("@/views/auth/PasswordResetView.vue"),
        meta: { guest: true },
    },
    {
        path: "/",
        component: PublicLayout,
        children: [
            {
                path: "",
                name: "home",
                component: () => import("@/views/public/HomeView.vue"),
            },
            {
                path: "products",
                name: "products",
                component: () => import("@/views/public/ProductListView.vue"),
            },
            {
                path: "products/:id",
                name: "product-detail",
                component: () => import("@/views/public/ProductDetailView.vue"),
            },
            {
                path: "knowledge",
                name: "knowledge",
                component: () =>
                    import("@/views/public/KnowledgeCenterView.vue"),
            },
            {
                path: "knowledge/:id",
                name: "knowledge-detail",
                component: () =>
                    import("@/views/public/KnowledgeDetailView.vue"),
            },
            {
                path: "ai-service",
                name: "ai-service",
                component: () => import("@/views/ai/AiServiceView.vue"),
            },
        ],
    },
    {
        path: "/workspace",
        component: WorkspaceLayout,
        meta: { requiresAuth: true },
        children: [
            { path: "", redirect: "/workspace/profile" },
            {
                path: "cart",
                component: () => import("@/views/workspace/CartView.vue"),
            },
            {
                path: "checkout",
                component: () => import("@/views/workspace/CheckoutView.vue"),
            },
            {
                path: "orders",
                component: () => import("@/views/workspace/OrdersView.vue"),
            },
            {
                path: "orders/:id",
                component: () =>
                    import("@/views/workspace/OrderDetailView.vue"),
            },
            {
                path: "wallet",
                component: () => import("@/views/workspace/WalletView.vue"),
            },
            {
                path: "addresses",
                component: () => import("@/views/workspace/AddressView.vue"),
            },
            {
                path: "notifications",
                component: () =>
                    import("@/views/workspace/NotificationView.vue"),
            },
            {
                path: "profile",
                component: () => import("@/views/workspace/ProfileView.vue"),
            },
            {
                path: "training",
                component: () =>
                    import("@/views/training/TrainingTasksView.vue"),
            },
            {
                path: "training/courses",
                component: () =>
                    import("@/views/training/CourseCatalogView.vue"),
            },
            {
                path: "training/courses/:id",
                component: () =>
                    import("@/views/training/CourseDetailView.vue"),
            },
            {
                path: "training/chapters/:id",
                component: () =>
                    import("@/views/training/ChapterLearningView.vue"),
            },
            {
                path: "training/quiz/:gateId",
                component: () => import("@/views/training/QuizView.vue"),
            },
            {
                path: "training/progress",
                component: () =>
                    import("@/views/training/TrainingProgressView.vue"),
            },
        ],
    },
    {
        path: "/403",
        component: () => import("@/views/status/ForbiddenView.vue"),
    },
    {
        path: "/:pathMatch(.*)*",
        component: () => import("@/views/status/NotFoundView.vue"),
    },
];

const router = createRouter({
    history: createWebHistory(),
    routes,
    scrollBehavior: () => ({ top: 0 }),
});
router.beforeEach((to) => {
    const session = useSessionStore();
    if (to.meta.requiresAuth && !session.authenticated)
        return { path: "/login", query: { redirect: to.fullPath } };
    if (to.meta.guest && session.authenticated) return "/workspace/profile";
    return true;
});
export default router;
