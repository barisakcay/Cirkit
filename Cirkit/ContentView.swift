//
//  ContentView.swift
//  Cirkit
//
//  Created by Baris Akcay on 2.03.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @Query private var components: [Component]
    
    // Board Navigation State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    // UI Logic State
    @State private var isEditModeActive = false
    @State private var isShowingLibrary = false
    @State private var selectedComponentForEdit: Component?
    @State private var componentToPlace: (type: String, value: Double)?
    
    private let boardSize: CGFloat = 3000
    
    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    // 1. Adaptive Technical Grid
                    GridView(boardSize: boardSize)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1 / scale)
                        .background(Color(UIColor.systemBackground))
                        .frame(width: boardSize, height: boardSize)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            hideKeyboard()
                            if let pending = componentToPlace {
                                placeComponent(at: location, data: pending)
                            }
                        }
                    
                    // 2. Components Layer
                    ForEach(components) { component in
                        ZStack(alignment: .topTrailing) {
                            // Main Component Body
                            ComponentView(component: component, isEditing: isEditModeActive)
                                .rotationEffect(.degrees(component.rotation))
                                .onTapGesture {
                                    hideKeyboard()
                                    if !isEditModeActive && componentToPlace == nil {
                                        selectedComponentForEdit = component
                                    }
                                }
                            
                            // Edit Controls Overlay
                            if isEditModeActive {
                                VStack(spacing: 10) {
                                    Button(action: { deleteComponent(component) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .red)
                                    }
                                    
                                    Button(action: { withAnimation { component.rotation -= 90 } }) {
                                        Image(systemName: "rotate.left.fill")
                                            .foregroundStyle(.white, .blue)
                                    }
                                    
                                    Button(action: { withAnimation { component.rotation += 90 } }) {
                                        Image(systemName: "rotate.right.fill")
                                            .foregroundStyle(.white, .blue)
                                    }
                                }
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .offset(x: 45, y: -25)
                            }
                        }
                        .position(x: component.x, y: component.y)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if !isEditModeActive && componentToPlace == nil {
                                        component.x = value.location.x
                                        component.y = value.location.y
                                    }
                                }
                        )
                    }
                    
                    // Placement Indicator
                    if let pending = componentToPlace {
                        Text("Target: \(pending.type) - Tap to Place")
                            .font(.caption).bold().padding(8).background(.orange).foregroundColor(.white).cornerRadius(8)
                            .position(x: boardSize/2, y: 150 / scale)
                    }
                }
                .scaleEffect(scale)
                .frame(width: boardSize * scale, height: boardSize * scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 0.3), 3.0)
                        }
                        .onEnded { _ in lastScale = 1.0 }
                )
            }
            .navigationTitle("Cirkit")
            .sheet(isPresented: $isShowingLibrary) {
                ComponentLibraryView { type, value in
                    self.componentToPlace = (type, value)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedComponentForEdit) { component in
                ValuePickerView(component: component)
                    .presentationDetents([.medium])
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(action: { isShowingLibrary = true }) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        .disabled(isEditModeActive || componentToPlace != nil)
                        
                        Spacer()
                        
                        // Zoom HUD
                        HStack(spacing: 8) {
                            Button(action: { withAnimation { scale = max(scale - 0.2, 0.3) } }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            Text("\(Int(scale * 100))%").font(.system(.caption, design: .monospaced)).frame(width: 45)
                            Button(action: { withAnimation { scale = min(scale + 0.2, 3.0) } }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                        }
                        .padding(6).background(.ultraThinMaterial).cornerRadius(8)
                        
                        Spacer()
                        
                        Button(action: { withAnimation(.spring()) { isEditModeActive.toggle() } }) {
                            Text(isEditModeActive ? "Done" : "Edit Mode")
                                .bold().padding(.horizontal, 16).padding(.vertical, 8)
                                .background(isEditModeActive ? Color.blue : Color.red.opacity(0.1))
                                .foregroundColor(isEditModeActive ? .white : .red).cornerRadius(20)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Logic
    private func placeComponent(at location: CGPoint, data: (type: String, value: Double)) {
        let newComp = Component(name: data.type, x: location.x, y: location.y, value: data.value, type: data.type)
        modelContext.insert(newComp)
        componentToPlace = nil
    }
    
    private func deleteComponent(_ component: Component) {
        withAnimation { modelContext.delete(component) }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Component Library
struct ComponentLibraryView: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (String, Double) -> Void
    
    let types = ["Resistor", "Capacitor", "Inductor", "Voltage Source", "Current Source"]
    let e12Base: [Double] = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2]
    
    @State private var selectedType = "Resistor"
    @State private var selectedBase = 1.0
    @State private var selectedMultiplier: Double = 100
    @State private var manualValue: Double = 12.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Component") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                }
                
                if selectedType.contains("Source") {
                    Section("Value Input") {
                        TextField("Value", value: $manualValue, format: .number).keyboardType(.decimalPad)
                    }
                } else {
                    Section("E12 Series") {
                        Picker("Base", selection: $selectedBase) {
                            ForEach(e12Base, id: \.self) { Text(String(format: "%.1f", $0)).tag($0) }
                        }
                        Picker("Multiplier", selection: $selectedMultiplier) {
                            Text("x1").tag(1.0); Text("x1k").tag(1000.0); Text("x1M").tag(1000000.0)
                        }
                    }
                }
                
                Button("Confirm Selection") {
                    let val = selectedType.contains("Source") ? manualValue : (selectedBase * selectedMultiplier)
                    onSelect(selectedType, val)
                    dismiss()
                }
                .frame(maxWidth: .infinity).bold()
            }
            .navigationTitle("Library")
        }
    }
}

// MARK: - Schematic Component View
struct ComponentView: View {
    let component: Component
    let isEditing: Bool
    private let sw: CGFloat = 60
    private let sh: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Polarities
                HStack {
                    Text("+").font(.caption2).bold().offset(y: -22)
                    Spacer()
                    Text("-").font(.caption2).bold().offset(y: -22)
                }
                .frame(width: sw + 20)
                .foregroundColor(.secondary)
                
                // Wire Ends
                Path { p in
                    p.move(to: CGPoint(x: -15, y: sh/2)); p.addLine(to: CGPoint(x: 0, y: sh/2))
                    p.move(to: CGPoint(x: sw, y: sh/2)); p.addLine(to: CGPoint(x: sw+15, y: sh/2))
                }
                .stroke(isEditing ? Color.orange : Color.brown, lineWidth: 2)
                
                // Symbol
                symbolPath(for: component.type)
                    .stroke(isEditing ? Color.orange : Color.brown, lineWidth: 2)
            }
            .frame(width: sw, height: sh)
            
            // Value (Counter-rotation for readability)
            Text(formatVal(component.value, type: component.type))
                .font(.system(.caption2, design: .monospaced)).bold()
                .padding(4).background(.thinMaterial).cornerRadius(4)
                .rotationEffect(.degrees(-component.rotation))
        }
    }
    
    private func symbolPath(for type: String) -> Path {
        switch type {
        case "Resistor":
            return Path { p in
                p.move(to: CGPoint(x: 0, y: sh/2))
                for i in 1...6 { p.addLine(to: CGPoint(x: CGFloat(i)*(sw/6), y: (i%2==1 ? 0 : sh))) }
                p.addLine(to: CGPoint(x: sw, y: sh/2))
            }
        case "Capacitor":
            return Path { p in
                p.move(to: CGPoint(x: sw*0.4, y: 0)); p.addLine(to: CGPoint(x: sw*0.4, y: sh))
                p.move(to: CGPoint(x: sw*0.6, y: 0)); p.addLine(to: CGPoint(x: sw*0.6, y: sh))
                p.move(to: CGPoint(x: 0, y: sh/2)); p.addLine(to: CGPoint(x: sw*0.4, y: sh/2))
                p.move(to: CGPoint(x: sw*0.6, y: sh/2)); p.addLine(to: CGPoint(x: sw, y: sh/2))
            }
        case "Inductor":
            return Path { p in
                p.move(to: CGPoint(x: 0, y: sh/2))
                for i in 0..<4 {
                    let x = CGFloat(i)*(sw/4)
                    p.addCurve(to: CGPoint(x: x+(sw/4), y: sh/2), control1: CGPoint(x: x+(sw/8), y: -sh*0.3), control2: CGPoint(x: x+(sw*3/8), y: -sh*0.3))
                }
            }
        case "Voltage Source":
            return Path { p in
                p.addEllipse(in: CGRect(x: 0, y: -sh/4, width: sw, height: sw))
                p.move(to: CGPoint(x: sw*0.3, y: sh/2)); p.addLine(to: CGPoint(x: sw*0.5, y: sh/2))
                p.move(to: CGPoint(x: sw*0.4, y: sh*0.3)); p.addLine(to: CGPoint(x: sw*0.4, y: sh*0.7))
            }
        case "Current Source":
            return Path { p in
                p.addEllipse(in: CGRect(x: 0, y: -sh/4, width: sw, height: sw))
                p.move(to: CGPoint(x: sw*0.2, y: sh/2)); p.addLine(to: CGPoint(x: sw*0.8, y: sh/2))
                p.addLine(to: CGPoint(x: sw*0.6, y: sh*0.2)); p.move(to: CGPoint(x: sw*0.8, y: sh/2)); p.addLine(to: CGPoint(x: sw*0.6, y: sh*0.8))
            }
        default: return Path()
        }
    }
    
    private func formatVal(_ v: Double, type: String) -> String {
        let u = ["Resistor":"Ω", "Capacitor":"F", "Inductor":"H", "Voltage Source":"V", "Current Source":"A"][type] ?? ""
        if v >= 1_000_000 { return "\(Int(v/1_000_000))M\(u)" }
        if v >= 1_000 { return "\(Int(v/1_000))k\(u)" }
        return "\(Int(v))\(u)"
    }
}

// MARK: - UI Helpers
struct GridView: Shape {
    let boardSize: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in stride(from: 0, to: boardSize, by: 50) {
            path.move(to: CGPoint(x: i, y: 0)); path.addLine(to: CGPoint(x: i, y: boardSize))
            path.move(to: CGPoint(x: 0, y: i)); path.addLine(to: CGPoint(x: boardSize, y: i))
        }
        return path
    }
}

struct ValuePickerView: View {
    @Bindable var component: Component
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Update Value") {
                    TextField("Value", value: $component.value, format: .number).keyboardType(.decimalPad)
                }
                Button("Save") { dismiss() }.frame(maxWidth: .infinity)
            }
            .navigationTitle("Edit")
        }
    }
}

// MARK: - Preview
//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Component.self, configurations: config)
//    return ContentView().modelContainer(container)
//}
