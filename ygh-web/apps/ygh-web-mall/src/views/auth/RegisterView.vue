<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import {
  fetchCaptcha,
  register,
  sessionUserFromAuthentication,
  useSessionStore,
  type CaptchaChallenge,
} from '@ygh/web-shared'
import { useHttp } from '@/api/client'

const router = useRouter()
const session = useSessionStore()
const loading = ref(false)
const captcha = ref<CaptchaChallenge>()
const form = reactive({ principal: '', password: '', confirmPassword: '', captchaAnswer: '', agreementAccepted: false })
const captchaSource = computed(() => captcha.value
  ? `data:${captcha.value.mimeType};base64,${captcha.value.imageBase64}`
  : '')

async function loadCaptcha() {
  try {
    captcha.value = await fetchCaptcha(useHttp())
  } catch {
    ElMessage.error('验证码加载失败，请稍后重试')
  }
}

async function submit() {
  if (!captcha.value) return
  loading.value = true
  try {
    const result = await register(useHttp(), {
      ...form,
      captchaChallengeId: captcha.value.challengeId,
    })
    session.establish(result.tokens, sessionUserFromAuthentication(result, form.principal))
    ElMessage.success('注册成功')
    await router.replace('/workspace/profile')
  } catch {
    ElMessage.error('注册失败，请检查资料或刷新验证码后重试')
    await loadCaptcha()
  } finally {
    loading.value = false
  }
}

onMounted(loadCaptcha)
</script>
<template><div class="register-page"><div class="register-card paper-card"><RouterLink to="/" class="brand"><span>粤</span><b class="serif">粤港甄选</b></RouterLink><h1 class="serif">创建平台账号</h1><p>用于跨境购物、知识咨询和员工学习。员工岗位由管理员在后台关联。</p><el-form label-position="top" @submit.prevent="submit"><el-form-item label="用户名 / 手机号 / 邮箱"><el-input v-model="form.principal" size="large" autocomplete="username"/></el-form-item><el-form-item label="登录密码"><el-input v-model="form.password" size="large" type="password" show-password autocomplete="new-password"/></el-form-item><el-form-item label="确认密码"><el-input v-model="form.confirmPassword" size="large" type="password" show-password autocomplete="new-password"/></el-form-item><el-form-item label="图形验证码"><div class="captcha-row"><el-input v-model="form.captchaAnswer" size="large" maxlength="32"/><button type="button" class="captcha" title="点击刷新验证码" @click="loadCaptcha"><img v-if="captchaSource" :src="captchaSource" alt="图形验证码"/><span v-else>重新加载</span></button></div></el-form-item><el-checkbox v-model="form.agreementAccepted">我已阅读并同意平台服务条款与隐私说明</el-checkbox><el-button native-type="submit" type="primary" size="large" class="submit" :loading="loading" :disabled="!form.agreementAccepted || !captcha">注册账号</el-button></el-form><div class="login">已有账号？<RouterLink to="/login">返回登录</RouterLink></div></div></div></template>
<style scoped>.register-page{min-height:100vh;display:grid;place-items:center;padding:50px 20px;background:linear-gradient(135deg,#d9e7df,#f1eadc)}.register-card{width:min(520px,100%);padding:38px 44px}.brand{display:flex;align-items:center;gap:10px}.brand span{display:grid;place-items:center;width:32px;height:32px;background:var(--cinnabar);color:#fff}.register-card h1{margin:24px 0 8px}.register-card>p{margin-bottom:25px;color:var(--muted);line-height:1.7}.captcha-row{display:grid;grid-template-columns:1fr 150px;gap:10px;width:100%}.captcha{height:40px;border:1px solid #c8c3b5;background:#fff;cursor:pointer}.captcha img{width:100%;height:100%;object-fit:contain}.submit{width:100%;margin-top:22px}.login{margin-top:20px;text-align:center;color:var(--muted);font-size:13px}.login a{color:var(--jade);font-weight:600}</style>
