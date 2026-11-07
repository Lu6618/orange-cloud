//
//  D1DeleteConfirmView.swift
//  Orange Cloud
//
//  D1 数据库删除二次确认（Sheet）：名称自动填入，核对后点删除即可
//  （原为手动输入确认，2026-11-07 按 Lu 要求改自动填入）。入口（StorageView 滑动删除）已按
//  d1.write 门控。删除连同全部表与数据，不可恢复。
//

import SwiftUI

struct D1DeleteConfirmView: View {

    let database: D1Database
    let viewModel: D1DatabaseListViewModel
    let accountId: String

    @Environment(\.dismiss) private var dismiss
    @State private var typedName = ""
    @FocusState private var fieldFocused: Bool

    /// 输入与库名完全一致（去空白）才允许删除
    private var nameMatches: Bool {
        typedName.trimmingCharacters(in: .whitespacesAndNewlines) == database.name
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
                        Text("永久删除数据库")
                            .font(.headline)
                        Text("此操作将永久删除数据库 \(database.name) 及其全部表和数据，无法撤销，也无法恢复。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(database.name, text: $typedName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await performDelete() } }
                } header: {
                    Text("确认数据库名称")
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
            .navigationTitle("删除数据库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { typedName = database.name }
            .interactiveDismissDisabled(viewModel.isDeleting)
        }
    }

    private func performDelete() async {
        guard canDelete else { return }
        fieldFocused = false
        if await viewModel.delete(accountId: accountId, database: database) {
            dismiss()
        }
    }
}
