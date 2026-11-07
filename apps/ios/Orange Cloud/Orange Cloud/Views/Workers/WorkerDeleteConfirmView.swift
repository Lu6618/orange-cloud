//
//  WorkerDeleteConfirmView.swift
//  Orange Cloud
//
//  Worker 脚本删除二次确认（Sheet）：名称自动填入，核对后点删除即可
//  （原为手动输入确认，2026-11-07 按 Lu 要求改自动填入；注意：打开即满足删除条件，
//  误删风险高于手动输入版）。入口（WorkerListView 滑动删除）已按
//  workers-scripts.write 门控。删除连同其部署与路由绑定，不可恢复。
//

import SwiftUI
import SwiftData

struct WorkerDeleteConfirmView: View {

    let script: CachedWorkerScript
    let viewModel: WorkerListViewModel
    let accountId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var typedName = ""
    @FocusState private var fieldFocused: Bool

    /// 输入与脚本名完全一致（去空白）才允许删除
    private var nameMatches: Bool {
        typedName.trimmingCharacters(in: .whitespacesAndNewlines) == script.id
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
                        Text("此操作将永久删除 Worker \(script.id) 及其部署与路由绑定，无法撤销，也无法恢复。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(script.id, text: $typedName)
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
            .onAppear { typedName = script.id }
            .interactiveDismissDisabled(viewModel.isDeleting)
        }
    }

    private func performDelete() async {
        guard canDelete else { return }
        fieldFocused = false
        // 先调服务端删除；成功后记下待清缓存的脚本并关 sheet，缓存清理由列表在
        // sheet 完全关闭后的 onDismiss 里做——关闭动画中 sheet 仍持有 script 对象，
        // 此时清缓存会让重绘访问已删对象导致闪退；build-6 的 350ms 等待仍不够，改用 onDismiss。
        // 服务端删除失败时留在本页显示错误，不关 sheet。
        guard await viewModel.deleteFromServer(accountId: accountId, scriptName: script.id) else { return }
        viewModel.pendingDelete = script
        dismiss()
    }
}
