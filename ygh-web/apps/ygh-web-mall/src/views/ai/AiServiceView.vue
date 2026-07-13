<script setup lang="ts">
import { nextTick, onMounted, ref } from "vue";
import { useRoute } from "vue-router";
import {
    ChatDotRound,
    Delete,
    Document,
    Promotion,
} from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import { useSessionStore, type ChatMessage } from "@ygh/web-shared";
import {
    listConversationMessages,
    listConversations,
    streamChat,
    submitAiFeedback,
    type Conversation,
} from "@/api/ai";
const session = useSessionStore();
const route = useRoute();
const input = ref(String(route.query.q || ""));
const sending = ref(false);
const scroll = ref<HTMLElement>();
const welcome: ChatMessage = {
    id: "welcome",
    role: "ASSISTANT",
    content:
        "您好，我是跨境智汇 AI 客服。我可以依据已发布知识和授权商品信息，回答跨境政策、通关流程、商品溯源以及您的订单问题。",
    createdAt: new Date().toISOString(),
};
const messages = ref<ChatMessage[]>([welcome]);
const conversations = ref<Conversation[]>([]);
const conversationId = ref<string>();
const feedbackMessages = ref(new Set<string>());
let controller: AbortController | undefined;
async function loadConversations() {
    if (session.authenticated)
        try {
            conversations.value = (await listConversations()).map((x) => ({
                ...x,
                time: new Date(x.updatedAt).toLocaleString("zh-CN"),
            }));
        } catch {
            ElMessage.error("历史会话加载失败");
        }
}
async function openConversation(id: string) {
    try {
        conversationId.value = id;
        const history = await listConversationMessages(id);
        messages.value = [
            welcome,
            ...history.map((x) => ({
                id: x.id,
                role: x.role,
                content: x.content,
                createdAt: x.createdAt,
                refused: x.refused,
                citations: x.citations.map((citation) => ({
                    documentId: citation.documentId,
                    chunkId: citation.sourceId,
                    title: citation.title,
                    excerpt: `${citation.excerpt}${citation.documentVersion ? `（版本 ${citation.documentVersion}${citation.sourceUpdatedAt ? `，更新于 ${new Date(citation.sourceUpdatedAt).toLocaleString("zh-CN")}` : ""}）` : ""}`,
                })),
            })),
        ];
    } catch {
        ElMessage.error("会话消息加载失败");
    }
}
function newChat() {
    controller?.abort();
    conversationId.value = undefined;
    messages.value = [welcome];
}
async function send() {
    const text = input.value.trim();
    if (!text || sending.value) return;
    if (!session.authenticated) {
        ElMessage.warning("请先登录后使用 AI 客服");
        return;
    }
    messages.value.push({
        id: crypto.randomUUID(),
        role: "USER",
        content: text,
        createdAt: new Date().toISOString(),
    });
    const answer: ChatMessage = {
        id: crypto.randomUUID(),
        role: "ASSISTANT",
        content: "",
        createdAt: new Date().toISOString(),
    };
    messages.value.push(answer);
    input.value = "";
    sending.value = true;
    controller = new AbortController();
    await nextTick();
    scroll.value?.scrollTo({ top: scroll.value.scrollHeight });
    try {
        const result = await streamChat(
            {
                conversationId: conversationId.value,
                message: text,
                includeOwnOrders: true,
            },
            session.bearer,
            (delta) => {
                answer.content += delta;
                nextTick(() =>
                    scroll.value?.scrollTo({ top: scroll.value!.scrollHeight }),
                );
            },
            controller.signal,
        );
        answer.id = result.messageId || answer.id;
        answer.citations = result.citations;
        answer.refused = result.refused;
        conversationId.value = result.conversationId;
        await loadConversations();
    } catch (error) {
        if ((error as Error).name !== "AbortError") {
            answer.content = "回答生成失败，请稍后重试。";
            ElMessage.error("AI 流式回答失败");
        }
    } finally {
        sending.value = false;
        controller = undefined;
    }
}
async function feedback(messageId: string, helpful: boolean) {
    try {
        await submitAiFeedback(messageId, helpful);
        feedbackMessages.value.add(messageId);
        ElMessage.success("感谢反馈，结果将用于离线评测与治理");
    } catch {
        ElMessage.error("反馈提交失败");
    }
}
onMounted(loadConversations);
</script>
<template>
    <div class="ai-shell">
        <aside>
            <div class="ai-brand">
                <span>AI</span>
                <div><b>跨境智汇客服</b><small>可信检索增强问答</small></div>
            </div>
            <el-button
                type="primary"
                plain
                class="new-chat"
                :icon="ChatDotRound"
                @click="newChat"
                >新建会话</el-button
            >
            <p>最近会话</p>
            <button
                v-for="c in conversations"
                :key="c.id"
                @click="openConversation(c.id)"
            >
                <ChatDotRound /><span
                    ><b>{{ c.title }}</b
                    ><small>{{ c.time }}</small></span
                >
            </button>
            <div class="ai-boundary">
                <b>能力边界</b><span>✓ 已发布知识</span><span>✓ 商品与溯源</span
                ><span>✓ 本人订单只读</span><span>× 不修改交易数据</span>
            </div>
        </aside>
        <main>
            <header>
                <div>
                    <span class="status-dot" /><b>专业客服在线</b
                    ><small>回答由知识库与业务工具共同支撑</small>
                </div>
                <el-button text :icon="Delete" @click="newChat">清空</el-button>
            </header>
            <div ref="scroll" class="messages">
                <div v-if="!session.authenticated" class="login-notice">
                    <b>登录后可查询本人订单与保存历史会话</b
                    ><el-button
                        size="small"
                        type="primary"
                        @click="$router.push('/login')"
                        >去登录</el-button
                    >
                </div>
                <article
                    v-for="m in messages"
                    :key="m.id"
                    :class="m.role.toLowerCase()"
                >
                    <div class="avatar">
                        {{ m.role === "USER" ? "我" : "智" }}
                    </div>
                    <div class="message-body">
                        <div class="bubble">{{ m.content }}</div>
                        <div v-if="m.citations?.length" class="citations">
                            <b
                                ><Document />回答引用
                                {{ m.citations.length }} 条</b
                            ><RouterLink
                                v-for="c in m.citations"
                                :key="c.chunkId"
                                :to="`/knowledge/${c.documentId}`"
                                ><span>{{ c.title }}</span
                                ><small>{{ c.excerpt }}</small></RouterLink
                            >
                        </div>
                        <div
                            v-if="m.role === 'ASSISTANT' && m.id !== 'welcome'"
                            class="feedback"
                        >
                            <span v-if="feedbackMessages.has(m.id)"
                                >已反馈</span
                            >
                            <template v-else
                                ><span>这个回答有帮助吗？</span
                                ><el-button link @click="feedback(m.id, true)"
                                    >有帮助</el-button
                                ><el-button link @click="feedback(m.id, false)"
                                    >需改进</el-button
                                ></template
                            >
                        </div>
                    </div>
                </article>
                <article v-if="sending" class="assistant">
                    <div class="avatar">智</div>
                    <div class="bubble typing"><i /><i /><i /></div>
                </article>
            </div>
            <footer>
                <div class="suggestions">
                    <button
                        v-for="q in [
                            '进口零食需要哪些通关材料？',
                            '如何查看商品溯源？',
                            '查询我的待支付订单',
                        ]"
                        :key="q"
                        @click="input = q"
                    >
                        {{ q }}
                    </button>
                </div>
                <div class="composer">
                    <el-input
                        v-model="input"
                        type="textarea"
                        :autosize="{ minRows: 2, maxRows: 5 }"
                        maxlength="1000"
                        show-word-limit
                        placeholder="请输入跨境政策、商品溯源或订单问题……"
                        @keydown.ctrl.enter.prevent="send"
                    /><el-button
                        type="primary"
                        :icon="Promotion"
                        :loading="sending"
                        @click="send"
                        >发送</el-button
                    >
                </div>
                <small>AI 可能出错，请核对引用来源。Ctrl + Enter 发送。</small>
            </footer>
        </main>
    </div>
</template>
<style scoped>
.ai-shell {
    height: calc(100vh - 102px);
    min-height: 650px;
    display: grid;
    grid-template-columns: 270px 1fr;
    background: #edf1ec;
}
.ai-shell > aside {
    display: flex;
    flex-direction: column;
    padding: 22px;
    background: #0b3431;
    color: white;
}
.ai-brand {
    display: flex;
    align-items: center;
    gap: 11px;
}
.ai-brand > span {
    display: grid;
    place-items: center;
    width: 40px;
    height: 40px;
    border: 1px solid #d7bc75;
    color: #d7bc75;
    font: 700 14px serif;
}
.ai-brand b,
.ai-brand small {
    display: block;
}
.ai-brand small {
    margin-top: 3px;
    color: #8eaaa3;
    font-size: 10px;
}
.new-chat {
    width: 100%;
    margin: 24px 0;
}
.ai-shell aside > p {
    color: #77928c;
    font-size: 11px;
    letter-spacing: 0.14em;
}
.ai-shell aside > button {
    display: flex;
    gap: 10px;
    padding: 11px 8px;
    border: 0;
    border-radius: 7px;
    background: transparent;
    color: #bed0cb;
    text-align: left;
    cursor: pointer;
}
.ai-shell aside > button:hover {
    background: rgba(255, 255, 255, 0.07);
}
.ai-shell aside > button svg {
    width: 15px;
}
.ai-shell aside > button b,
.ai-shell aside > button small {
    display: block;
}
.ai-shell aside > button b {
    font-size: 12px;
}
.ai-shell aside > button small {
    margin-top: 3px;
    color: #708d86;
    font-size: 10px;
}
.ai-boundary {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: auto;
    padding: 16px;
    background: rgba(255, 255, 255, 0.05);
    font-size: 11px;
}
.ai-boundary b {
    color: #d7bc75;
    margin-bottom: 3px;
}
.ai-shell > main {
    min-width: 0;
    display: grid;
    grid-template-rows: 64px 1fr auto;
    background: #faf9f5;
}
.ai-shell main > header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 24px;
    background: #fff;
    border-bottom: 1px solid var(--line);
}
.ai-shell main > header > div {
    display: flex;
    align-items: center;
    gap: 10px;
}
.ai-shell main > header small {
    color: var(--muted);
}
.messages {
    overflow: auto;
    padding: 25px max(24px, calc((100% - 850px) / 2));
}
.login-notice {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 20px;
    padding: 12px 15px;
    background: #fff3d6;
    border: 1px solid #e5c980;
    color: #765d23;
    font-size: 12px;
}
.messages article {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    margin: 20px 0;
}
.messages article.user {
    flex-direction: row-reverse;
}
.avatar {
    flex: 0 0 34px;
    height: 34px;
    display: grid;
    place-items: center;
    background: var(--jade);
    color: #fff;
    border-radius: 50%;
    font: 700 13px serif;
}
.user .avatar {
    background: var(--cinnabar);
}
.message-body {
    max-width: min(78%, 700px);
}
.bubble {
    padding: 13px 16px;
    background: #fff;
    border: 1px solid var(--line);
    border-radius: 2px 13px 13px 13px;
    line-height: 1.8;
    font-size: 14px;
}
.user .bubble {
    background: var(--jade);
    border: 0;
    border-radius: 13px 2px 13px 13px;
    color: white;
}
.citations {
    margin-top: 7px;
    padding: 12px;
    background: #edf4f0;
    border-left: 3px solid var(--jade);
}
.citations > b {
    display: flex;
    align-items: center;
    gap: 5px;
    color: var(--jade);
    font-size: 11px;
}
.citations svg {
    width: 13px;
}
.citations a {
    display: block;
    margin-top: 8px;
}
.citations a span,
.citations a small {
    display: block;
}
.feedback {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 6px;
    color: var(--muted);
    font-size: 11px;
}
.citations a span {
    font-size: 12px;
    font-weight: 600;
}
.citations a small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 10px;
}
.typing {
    display: flex;
    gap: 4px;
}
.typing i {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #87a39c;
    animation: pulse 1s infinite;
}
.typing i:nth-child(2) {
    animation-delay: 0.15s;
}
.typing i:nth-child(3) {
    animation-delay: 0.3s;
}
@keyframes pulse {
    50% {
        opacity: 0.25;
        transform: translateY(-3px);
    }
}
.ai-shell main > footer {
    padding: 13px max(24px, calc((100% - 850px) / 2)) 16px;
    background: #fff;
    border-top: 1px solid var(--line);
}
.suggestions {
    display: flex;
    gap: 7px;
    margin-bottom: 8px;
    overflow: auto;
}
.suggestions button {
    padding: 6px 10px;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: #faf9f5;
    color: var(--muted);
    font-size: 10px;
    white-space: nowrap;
    cursor: pointer;
}
.composer {
    display: flex;
    align-items: end;
    gap: 9px;
}
.composer .el-button {
    height: 54px;
}
.ai-shell main > footer > small {
    display: block;
    margin-top: 6px;
    color: #9aa49f;
    font-size: 9px;
    text-align: center;
}
@media (max-width: 750px) {
    .ai-shell {
        grid-template-columns: 1fr;
    }
    .ai-shell > aside {
        display: none;
    }
    .message-body {
        max-width: 88%;
    }
}
</style>
