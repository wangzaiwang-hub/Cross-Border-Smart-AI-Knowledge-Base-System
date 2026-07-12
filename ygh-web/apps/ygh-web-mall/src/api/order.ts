import { apiData } from '@ygh/web-shared'
import { useHttp } from './client'

export interface Order {
  orderId: string
  orderNo: string
  userId: string
  status: string
  totalAmount: string
  currency: string
  version: number
  createdAt: string
}
export interface OrderItemCommand { skuId:string;skuCode:string;productName:string;unitPrice:string;quantity:number }
export interface AddressSnapshot { recipientName:string;recipientPhone:string;countryCode:string;provinceCode?:string;provinceName:string;cityName:string;districtName:string;addressDetail:string;postalCode?:string }
export interface CreateOrderCommand { requestId:string;items:OrderItemCommand[];address:AddressSnapshot;remark?:string }
export interface OrderPreview { items:OrderItemCommand[];totalAmount:string;currency:string;address:AddressSnapshot;warnings:string[] }

export async function listMyOrders(status?: string, limit = 50): Promise<Order[]> {
  return apiData(await useHttp().get('/api/v1/orders', { params: { status, limit } }))
}

export async function getOrder(id: string): Promise<Order> {
  return apiData(await useHttp().get(`/api/v1/orders/${id}`))
}

export async function cancelOrder(order: Order): Promise<Order> {
  return apiData(await useHttp().post(`/api/v1/orders/${order.orderId}/cancel`, undefined, { params: { version: order.version } }))
}

export async function requestOrderRefund(order: Order): Promise<Order> {
  return apiData(await useHttp().post(`/api/v1/orders/${order.orderId}/refund`, undefined, { params: { version: order.version } }))
}

export async function payOrder(order: Order): Promise<void> {
  const requestId = crypto.randomUUID()
  await useHttp().post('/api/v1/wallet/payments', { requestId, referenceId: order.orderId, amount: order.totalAmount, currency: order.currency })
}
export async function previewOrder(command:CreateOrderCommand):Promise<OrderPreview>{return apiData(await useHttp().post('/api/v1/orders/preview',command))}
export async function createOrder(command:CreateOrderCommand):Promise<Order>{return apiData(await useHttp().post('/api/v1/orders',command))}
