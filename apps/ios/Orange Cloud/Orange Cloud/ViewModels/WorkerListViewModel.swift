//
//  WorkerListViewModel.swift
//  Orange Cloud
//
//  拉取 Workers 脚本列表并同步进 SwiftData 缓存，View 通过 @Query 渲染。
//

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class WorkerListViewModel {

    var isLoading = false
    var error: String?
    var isDeleting = false
    var didDelete = false       // sensoryFeedback 触发器
    /// 服务端删除成功后，列表需在 sheet 关闭后刷新对账（见 WorkerListView onDismiss）。
    var needsRefreshAfterDelete = false

    private let workerService: WorkerService
    /// 进行中的加载任务（见 ZoneListViewModel：独立 Task 承载加载，避免下拉手势取消导致 .cancelled 误报）
    private var loadTask: Task<Void, Never>?

    init(workerService: WorkerService) {
        self.workerService = workerService
    }

    /// 从 API 刷新并 upsert 进缓存（共享逻辑见 CacheSync，仅限当前账号）
    func refresh(accountId: String, context: ModelContext) async {
        // 复用进行中的加载，并把网络加载放进独立 Task：下拉手势 / searchable 取消
        // .refreshable 子任务时不波及加载，避免 URLError.cancelled 误报为加载失败
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.load(accountId: accountId, context: context)
        }
        loadTask = task
        defer { loadTask = nil }
        await task.value
    }

    /// 删除 Worker 脚本（只调服务端，不动缓存）。缓存由列表刷新对账：
    /// syncWorkers 会删掉远端已不存在的条目，且刷新时确认页早已关闭。
    /// 删除流程里不做 context.delete——build-4/6/7 的闪退都是关闭动画中重绘访问
    /// 已删 SwiftData 对象所致，2026-11-07 实测三版皆崩，改由刷新对账才彻底。
    /// 需 workers-scripts.write。
    func deleteFromServer(accountId: String, scriptName: String) async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        error = nil
        defer { isDeleting = false }
        do {
            try await workerService.deleteScript(accountId: accountId, scriptName: scriptName)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func load(accountId: String, context: ModelContext) async {
        isLoading = true
        error = nil
        do {
            let scripts = try await workerService.listScripts(accountId: accountId)
            CacheSync.syncWorkers(scripts, accountId: accountId, context: context)
        } catch is CancellationError {
            // 任务取消属正常生命周期，不算加载失败
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession 把任务取消转成 .cancelled，同样不展示为错误
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
