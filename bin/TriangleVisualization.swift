import SwiftUI

struct TriangleVisualization: View {
    
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, arg in
                let canvasWidth = geometry.size.width
                let canvasHeight = geometry.size.height
                
                // Data bounds
                let dataWidth: CGFloat = 120
                let dataHeight: CGFloat = 100
                
                // Calculate scale factors to fit the canvas
                let scaleX = canvasWidth / dataWidth
                let scaleY = canvasHeight / dataHeight
                
                // Draw black background
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)),
                    with: .color(.black)
                )
                
                // Draw each triangle
                for triangle in triangles {
                    var path = Path()
                    path.move(to: CGPoint(
                        x: triangle[0][0] * scaleX,
                        y: triangle[0][1] * scaleY
                    ))
                    path.addLine(to: CGPoint(
                        x: triangle[1][0] * scaleX,
                        y: triangle[1][1] * scaleY
                    ))
                    path.addLine(to: CGPoint(
                        x: triangle[2][0] * scaleX,
                        y: triangle[2][1] * scaleY
                    ))
                    path.closeSubpath()
                    
                    context.fill(path, with: .color(.green))
                }
            }
            .background(Color.black)
        }
    }
}

#Preview {
    TriangleVisualization()
        .frame(width: 600, height: 500)
}
