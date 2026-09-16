import SwiftUI

// MARK: - 左滑操作卡片：tap/滑动统一裁决，滑动永不误触发打开
// 原理：卡片不再是 Button。SwipeToDeleteCard 自己接 DragGesture + TapGesture，
// 规则——一次触摸里横向位移 > 10pt 即判定为滑动，本次触摸永远不触发 onOpen。

struct SwipeToDeleteCard<Content: View>: View {
    let shade: DecorShade
    let onOpen: () -> Void      // 干净的 tap 才触发（进远程）
    let onRename: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offsetX: CGFloat = 0
    @State private var dragX: CGFloat = 0
    @State private var isHorizontalDrag = false

    private let actionWidth: CGFloat = 150   // 重命名 + 删除两颗按钮总宽

    private var currentOffset: CGFloat {
        if dragX != 0 { return min(0, max(-actionWidth - 24, offsetX + dragX)) }
        return offsetX
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offsetX = 0 }
                    onRename()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("重命名").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 78)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offsetX = 0 }
                    onDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("删除").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 78)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .opacity(currentOffset < -12 ? 1 : 0)
            .padding(.trailing, 6)

            content
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                // 开档（offsetX != 0）时不挂滑动手势：手指直接落在露出的按钮上即可点
                .gesture(offsetX == 0 ? slideGesture : nil)
                .simultaneousGesture(tapGesture)       // 干净 tap → 打开
        }
    }

    /// 横向滑动：onChanged 里实时判定横向主导，一旦判定为滑动，
    /// dragX 持续更新；tapGesture 的 onEnded 检查 isHorizontalDrag 决定是否打开
    private var slideGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { g in
                guard abs(g.translation.width) > abs(g.translation.height) else { return }
                if !isHorizontalDrag, abs(g.translation.width) > 10 {
                    isHorizontalDrag = true          // 判定为滑动：本次触摸再也不算 tap
                    withAnimation(.easeOut(duration: 0.1)) {}
                }
                if isHorizontalDrag {
                    dragX = g.translation.width
                }
            }
            .onEnded { _ in
                defer {
                    dragX = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isHorizontalDrag = false     // 略延迟，压过后到的 tap
                    }
                }
                guard isHorizontalDrag else { return }
                let final = min(0, max(-actionWidth - 24, offsetX + dragX))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offsetX = final < -actionWidth / 2 ? -actionWidth : 0
                }
            }
    }

    /// 干净 tap：本次触摸未被判为滑动才打开
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded { _ in
                guard !isHorizontalDrag else { return }
                if offsetX != 0 {
                    // 已开档时点卡片：先收档，不打开
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offsetX = 0 }
                } else {
                    onOpen()
                }
            }
    }
}
