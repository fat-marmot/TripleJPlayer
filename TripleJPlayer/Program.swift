import Foundation

struct Program: Identifiable {
    let id = UUID()
    let title: String
    let presenter: String
    let image: URL
    let startTime: String
    let endTime: String
    let description: String
    
    static let placeholder = Program(
        title: "Loading...",
        presenter: "triple j",
        image: URL(string: "https://www.abc.net.au/cm/rimage/11948498-1x1-large.png?v=2")!,
        startTime: "",
        endTime: "",
        description: "Loading program information..."
    )
}
