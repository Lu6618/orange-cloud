//
//  WorkerDeleteConfirmView.swift
//  Orange Cloud
//
//  Worker 脚本删除二次确认（Sheet）：名称自动填入，核对后点删除即可
//  （原为手动输入确认，2026-11-07 按 Lu 要求改自动填入；注意：打开即满足删除条件，
//  误删风险高于手动输入版）。入口（WorkerListView 滑动删除）已按
//  workers-scripts.write 门控。删除连同其部署与路由绑定，不可恢复。
//  本页只传脚本名（String），不持有 CachedWorkerScript 对象；缓存由列表刷新对账，
//  删除流程里没有任何 context.delete（build-4/6/7 的闪退根因从写法上已排除）。
//

import SwiftUI

struct WorkerDeleteConfirmView: View {

    let scriptName: String
    let viewModel: WorkerListViewModel
    let accountId: String

    @Environment(\.dismiss) private var dismiss
    @State private var typedName = ""
    @FocusState private var fieldFocused: Bool

    /// 输入与脚本名完全一致（去空白）才允许删除
    private var nameMatches: Bool {
        typedName.trimmingCharacters(in: .whitespacesAndNewlines) == scriptName
    }

    private var canDelete: Bool {
        nameMatches && !accountId.isEmpty && !viewModel.isDeleting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.red)
                        Text("永久删除 Worker")
                            .font(.headline)
                        Text("此操作将永久删除 Worker \(scriptName) 及其部署与路由绑定，无法撤销，也无法恢复。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(scriptName, text: $typedName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await performDelete() } }
                } header: {
                    Text("确认 Worker 名称")
                } footer: {
                    Text("名称已自动填入，核对无误后点下方删除。")
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await performDelete() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isDeleting {
                                ProgressView()
                            } else {
                                Label("永久删除", systemImage: "trash")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canDelete)
                }
            }
            .navigationTitle("删除 Worker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { typedName = scriptName }
            .interactiveDismissDisabled(viewModel.isDeleting)
        }
    }

    private func performDelete() async {
        guard canDelete else { return }
        fieldFocused = false
        // 埋点：下次再闪退时，崩溃报告里的面包屑能证明点删除时走到了这里
        CrashReporter.recordBreadcrumb("Delete confirm tapped: \(scriptName)")
        // 点删除即关 sheet：行先从列表消失（列表 onDismiss 记下名字并乐观隐藏），
        // 服务端删除在后台做，成功后刷新对账，失败则行恢复并弹提示。
        // 本页只拿脚本名，不持有 SwiftData 对象；删除流程里没有任何 context.delete。
        viewModel.pendingDeleteName = scriptName
        dismiss()
    }
}
