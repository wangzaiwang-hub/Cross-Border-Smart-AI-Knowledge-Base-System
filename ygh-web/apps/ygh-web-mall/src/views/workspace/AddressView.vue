<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import {
  createAddress,
  deleteAddress,
  listMyAddresses,
  makeDefaultAddress,
  updateAddress,
  type Address,
} from '@/api/user'

const dialog = ref(false)
const loading = ref(true)
const saving = ref(false)
const editingId = ref<string>()
const addresses = ref<Address[]>([])
const empty = () => ({ label: '', recipientName: '', recipientPhone: '', countryCode: 'CN', provinceCode: '', provinceName: '', cityName: '', districtName: '', addressDetail: '', postalCode: '', defaultAddress: false, version: 0 })
const form = reactive(empty())

async function load() {
  loading.value = true
  try { addresses.value = await listMyAddresses() }
  catch { ElMessage.error('地址列表加载失败') }
  finally { loading.value = false }
}

function openCreate() { editingId.value = undefined; Object.assign(form, empty()); dialog.value = true }
function openEdit(address: Address) { editingId.value = address.id; Object.assign(form, address); dialog.value = true }

async function save() {
  saving.value = true
  try {
    if (editingId.value) await updateAddress(editingId.value, form)
    else await createAddress(form)
    dialog.value = false
    ElMessage.success('地址已保存')
    await load()
  } catch { ElMessage.error('地址保存失败，请检查必填项或版本冲突') }
  finally { saving.value = false }
}

async function remove(address: Address) {
  await ElMessageBox.confirm('删除后不可恢复，历史订单地址快照不会受到影响。', '确认删除')
  try { await deleteAddress(address.id, address.version); await load(); ElMessage.success('地址已删除') }
  catch { ElMessage.error('地址删除失败') }
}

async function makeDefault(address: Address) {
  try { await makeDefaultAddress(address.id, address.version); await load(); ElMessage.success('默认地址已更新') }
  catch { ElMessage.error('默认地址更新失败') }
}

onMounted(load)
</script>
<template><PageHeader title="收货地址" description="地址会在下单时生成不可变快照，后续修改不影响历史订单。"><el-button type="primary" @click="openCreate">新增地址</el-button></PageHeader><div v-loading="loading" class="address-grid"><el-empty v-if="!loading&&!addresses.length" description="暂无收货地址"/><article v-for="a in addresses" :key="a.id" class="paper-card"><header><b>{{a.recipientName}}</b><span>{{a.recipientPhone}}</span><el-tag v-if="a.defaultAddress" size="small">默认地址</el-tag></header><p>{{a.provinceName}}{{a.cityName}}{{a.districtName}}{{a.addressDetail}}</p><footer><el-button text @click="openEdit(a)">编辑</el-button><el-button text type="danger" @click="remove(a)">删除</el-button><el-button v-if="!a.defaultAddress" text @click="makeDefault(a)">设为默认</el-button></footer></article></div><el-dialog v-model="dialog" :title="editingId?'编辑收货地址':'新增收货地址'" width="560"><el-form label-position="top"><div class="two"><el-form-item label="收货人"><el-input v-model="form.recipientName" maxlength="80"/></el-form-item><el-form-item label="联系电话"><el-input v-model="form.recipientPhone" maxlength="24"/></el-form-item></div><div class="two"><el-form-item label="省份"><el-input v-model="form.provinceName"/></el-form-item><el-form-item label="城市"><el-input v-model="form.cityName"/></el-form-item></div><el-form-item label="区 / 县"><el-input v-model="form.districtName"/></el-form-item><el-form-item label="详细地址"><el-input v-model="form.addressDetail" type="textarea" maxlength="500"/></el-form-item><div class="two"><el-form-item label="地址标签"><el-input v-model="form.label" placeholder="家、公司等"/></el-form-item><el-form-item label="邮政编码"><el-input v-model="form.postalCode"/></el-form-item></div><el-checkbox v-model="form.defaultAddress">设为默认地址</el-checkbox></el-form><template #footer><el-button @click="dialog=false">取消</el-button><el-button type="primary" :loading="saving" @click="save">保存地址</el-button></template></el-dialog></template>
<style scoped>.address-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.address-grid article{padding:22px}.address-grid header{display:flex;align-items:center;gap:12px}.address-grid header span{color:var(--muted)}.address-grid header .el-tag{margin-left:auto}.address-grid p{min-height:45px;color:#455752;line-height:1.7}.address-grid footer{padding-top:12px;border-top:1px solid var(--line)}.two{display:grid;grid-template-columns:1fr 1fr;gap:14px}@media(max-width:650px){.address-grid,.two{grid-template-columns:1fr}}</style>
