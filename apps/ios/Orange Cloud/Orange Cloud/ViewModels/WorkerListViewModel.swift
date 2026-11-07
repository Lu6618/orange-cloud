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
    /// 确认页点删除后记下的脚本名（列表 onDismiss 消费，见 WorkerListView）。
    var pendingDeleteName: String?
    /// 乐观删除中正隐藏的名字：行先从列表消失，服务端删除在后台做（见 deleteAndRefresh）。
    var pendingDeletedNames: Set<String> = []
    /// 后台删除失败时的错误信息（列表弹提示）。
    var deleteError: String?
    /// 列表重建计数：删除时 +1，List 用它做 .id()，整表重建而不是做行删除动画。
    /// 崩溃日志（2026-11-07 14:51）证明闪退是 List 行数 diff 不一致
    /// （UICollectionView Invalid_Number_Of_Items_In_Section），不是之前以为的
    /// “读已删对象”；重建绕开 diff，这类闪退从机制上就不会再发生。
    var listVersion = 0

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

    /// 后台删除 Worker：先调服务端删除，成功后直接 load 刷新对账
    /// （syncWorkers 会删掉远端已不存在的条目；不用 refresh 的 loadTask 去重，
    /// 否则正好有刷新在跑时会直接返回、不重新拉取，删掉的行又会回来）。
    /// 失败时把乐观隐藏的名字放回列表并记 deleteError（列表弹提示）。
    /// 删除流程里没有任何 context.delete：确认页只拿名字、不持有 SwiftData 对象，
    /// 缓存只在刷新对账时由 syncWorkers 动——build-4/6/7 的闪退
    /// （关闭动画中重绘访问已删对象）从写法上不可能再发生。
    /// 需 workers-scripts.write。
    func deleteAndRefresh(accountId: String, scriptName: String, context: ModelContext) async {
        CrashReporter.recordBreadcrumb("deleteAndRefresh start: \(scriptName)")
        do {
            try await workerService.deleteScript(accountId: accountId, scriptName: scriptName)
            CrashReporter.recordBreadcrumb("deleteScript ok, load start: \(scriptName)")
            await load(accountId: accountId, context: context)
            CrashReporter.recordBreadcrumb("deleteAndRefresh done: \(scriptName)")
            pendingDeletedNames.remove(scriptName)
            didDelete.toggle()
        } catch {
            CrashReporter.recordBreadcrumb("deleteAndRefresh failed: \(scriptName): \(error.localizedDescription)")
            pendingDeletedNames.remove(scriptName)
            deleteError = error.localizedDescription
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
