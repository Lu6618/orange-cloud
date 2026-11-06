//
//  OAuthConfig.swift
//  Orange Cloud
//
//  在 Cloudflare Dashboard 创建 OAuth Client 后，填入真实 clientID。
//  redirect_uri 必须与 Dashboard 中注册的完全一致。
//

import Foundation

nonisolated enum OAuthConfig {
    /// Lu 自建的 OAuth Client（Cloudflare Dashboard → OAuth clients，
    /// 私有 client，仅限本账号成员授权），配合自建回调中转 orange.698668.xyz。
    /// PKCE 公开标识符，非机密。官方 client ID 与 o-c.do 中转不向第三方构建开放。
    static let clientID = "20f62645e61eb23fe2c2cdba3c37362f"

    /// 自定义 scheme，供 Web 后端 302 跳回 App
    static let callbackScheme = "orangecloud"

    // Cloudflare OAuth 只接受 https redirect_uri，指向 Web 后端回调中转（见 apps/web/README.md）
//    #if DEBUG
//    static let redirectURI = "http://localhost:3000/oauth/callback"
//    #else
    static let redirectURI = "https://orange.698668.xyz/oauth/callback"
//    #endif

    // Cloudflare OAuth 端点
    static let authorizationURL = URL(string: "https://dash.cloudflare.com/oauth2/auth")!
    static let tokenURL         = URL(string: "https://dash.cloudflare.com/oauth2/token")!
    static let revokeURL        = URL(string: "https://dash.cloudflare.com/oauth2/revoke")!
    static let userInfoURL      = URL(string: "https://dash.cloudflare.com/oauth2/userinfo")!
}
