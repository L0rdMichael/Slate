//
//  ContentView.swift
//  Slate
//
//  Created by MICHAEL on 22/09/2025.
//

//import SwiftUI
//
//struct ContentView: View {
//    var body: some View {
//        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, world!")
//        }
//        .padding()
//    }
//}
//
//#Preview {
//    ContentView()
//}

import SwiftUI
import Combine

// MARK: - Model
// Represents a single task, conforming to Codable to be easily saved and loaded.
struct Task: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var duration: TimeInterval // Total duration in seconds for timed tasks
    var elapsed: TimeInterval = 0
    var status: Status = .running
    var isTimed: Bool
    var creationDate: Date = Date()

    enum Status: String, Codable {
        case running, paused, completed
    }
}

// MARK: - ViewModel
// Manages all task-related logic, acting as the single source of truth for the UI.
@MainActor
class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    private var timer: AnyCancellable?
    
    // Key for saving data to UserDefaults
    private let tasksStorageKey = "SlateTasks"

    init() {
        loadTasks()
        startTimer()
    }

    // Filter tasks for today's view
    var todayTasks: [Task] {
        tasks.filter { Calendar.current.isDateInToday($0.creationDate) }
             .sorted(by: { $0.creationDate > $1.creationDate })
    }
    
    // Group all tasks by date for the history view
    var tasksByDate: [Date: [Task]] {
        let grouped = Dictionary(grouping: tasks) { task in
            Calendar.current.startOfDay(for: task.creationDate)
        }
        return grouped
    }

    func addTask(name: String, duration: TimeInterval) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newTask = Task(name: name, duration: duration, isTimed: duration > 0)
        tasks.insert(newTask, at: 0)
        saveTasks()
    }

    func togglePause(for task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = tasks[index].status == .running ? .paused : .running
        saveTasks()
    }

    func stopTask(for task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = .completed
        saveTasks()
    }

    private func startTimer() {
        // This timer fires every second to update the elapsed time for running tasks.
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            var didChange = false
            for i in self.tasks.indices {
                if self.tasks[i].status == .running {
                    self.tasks[i].elapsed += 1
                    didChange = true
                    if self.tasks[i].isTimed && self.tasks[i].elapsed >= self.tasks[i].duration {
                        self.tasks[i].elapsed = self.tasks[i].duration
                        self.tasks[i].status = .completed
                    }
                }
            }
            if didChange {
                self.saveTasks()
            }
        }
    }
    
    // MARK: - Data Persistence
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksStorageKey)
        }
    }

    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksStorageKey) {
            if let decoded = try? JSONDecoder().decode([Task].self, from: data) {
                tasks = decoded
                return
            }
        }
        tasks = [] // Start with an empty list if nothing is saved
    }
}

// MARK: - Main App Entry Point
//@main
//struct SlateApp: App {
//    @StateObject private var taskManager = TaskManager()
//
//    var body: some Scene {
//        // This creates the icon in the menu bar.
//        MenuBarExtra {
//            ContentView(taskManager: taskManager)
//        } label: {
//            // The icon that appears in the menu bar.
//            Image(systemName: "checklist")
//        }
//        .menuBarExtraStyle(.window) // Use a popover-style window
//    }
//}

// MARK: - Views

// Main view inside the popover
struct ContentView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var showingHistory = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(showingHistory: $showingHistory)
            
            Divider()

            if showingHistory {
                HistoryView(taskManager: taskManager)
            } else {
                TodayView(taskManager: taskManager)
            }
        }
        .frame(width: 360, height: 480)
    }
}

struct HeaderView: View {
    @Binding var showingHistory: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "slate.fill") // Using a beta icon name conceptually
                .font(.title2)
                .foregroundColor(.accentColor)
                .hidden() // Hidden for balance, real icon would go here

            Spacer()
            
            Text("Slate")
                .font(.headline)

            Spacer()

            Button {
                showingHistory.toggle()
            } label: {
                Image(systemName: showingHistory ? "checklist" : "calendar.badge.clock")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help(showingHistory ? "Show Today's Tasks" : "Show Task History")
        }
        .padding()
    }
}

// View for today's tasks
struct TodayView: View {
     @ObservedObject var taskManager: TaskManager
     
     var body: some View {
        VStack(spacing: 0) {
            NewTaskView(taskManager: taskManager)
                .padding()

            Divider()

            if taskManager.todayTasks.isEmpty {
                Spacer()
                Text("A fresh slate for today.")
                    .foregroundColor(.secondary)
                Text("Add a task to begin.")
                    .font(.caption)
//                    .foregroundColor(.tertiary)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(taskManager.todayTasks) { task in
                        TaskItemView(task: task, taskManager: taskManager)
                    }
                }
                .listStyle(.plain)
            }
            
            FooterView(tasks: taskManager.todayTasks)
        }
     }
}

// View for creating a new task with the drag gesture
struct NewTaskView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var taskName: String = ""
    @State private var dragTime: TimeInterval = 0
    @State private var isDragging: Bool = false
    
    var body: some View {
        VStack {
            TextField("What are you working on?", text: $taskName)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit {
                    taskManager.addTask(name: taskName, duration: 0)
                    taskName = ""
                }

            Divider().padding(.vertical, 4)

            Text(isDragging ? formatTime(dragTime) : "Drag down to set a timer, or press Enter")
                .font(.caption)
                .foregroundColor(isDragging ? .accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .padding(8)
                .contentShape(Rectangle()) // Make the whole area draggable
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !taskName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            isDragging = true
                            // Each point of vertical drag equals 30 seconds. Capped at 8 hours.
                            let newTime = max(0, value.translation.height * 30)
                            dragTime = min(newTime, 8 * 3600)
                        }
                        .onEnded { value in
                            if isDragging {
                                taskManager.addTask(name: taskName, duration: dragTime)
                                taskName = ""
                            }
                            isDragging = false
                            dragTime = 0
                        }
                )
        }
        .padding(12)
        .background(Color(.unemphasizedSelectedContentBackgroundColor))
        .cornerRadius(10)
    }
}


// View for a single task item in the list
struct TaskItemView: View {
    let task: Task
    @ObservedObject var taskManager: TaskManager

    private var progress: Double {
        guard task.isTimed && task.duration > 0 else { return 1.0 }
        return min(1.0, task.elapsed / task.duration)
    }
    
    private var progressColor: Color {
        switch task.status {
        case .running: return .accentColor
        case .paused: return .orange
        case .completed: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.name)
                    .strikethrough(task.status == .completed, color: .secondary)
                    .foregroundColor(task.status == .completed ? .secondary : .primary)
                
                Spacer()
                
                if task.status != .completed {
                    HStack(spacing: 12) {
                        Button {
                            taskManager.togglePause(for: task)
                        } label: {
                            Image(systemName: task.status == .running ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.plain)

                        Button {
                           taskManager.stopTask(for: task)
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Text("\(formatTimeDigital(task.elapsed))" + (task.isTimed ? " / \(formatTimeDigital(task.duration))" : ""))
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
        }
        .padding(.vertical, 8)
    }
}

// View for showing all past tasks
struct HistoryView: View {
    @ObservedObject var taskManager: TaskManager
    
    private var sorted: [Date] {
        taskManager.tasksByDate.keys.sorted(by: >)
    }

    var body: some View {
        List {
            ForEach(sorted, id: \.self) { date in
                Section(header: Text(formatDateHeader(date))) {
                    ForEach(taskManager.tasksByDate[date] ?? []) { task in
                        HStack {
                            Text(task.name)
                            Spacer()
//                                                        Text(task.creationDate)
                            Spacer()
                            Text(formatTime(task.elapsed))
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct FooterView: View {
    let tasks: [Task]

    private var runningCount: Int {
        tasks.filter { $0.status == .running }.count
    }
    private var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    var body: some View {
        Divider()
        HStack {
            Text("\(runningCount) running / \(completedCount) completed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
    }
}


// MARK: - Helper Functions
func formatTime(_ seconds: TimeInterval) -> String {
    if seconds < 60 { return "\(Int(seconds))s" }
    let minutes = Int(seconds) / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    return "\(hours)h \(minutes % 60)m"
}

func formatTimeDigital(_ totalSeconds: TimeInterval) -> String {
    let hours = Int(totalSeconds) / 3600
    let minutes = (Int(totalSeconds) % 3600) / 60
    let seconds = Int(totalSeconds) % 60
    return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
}

func formatDateHeader(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "Today" }
    if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter.string(from: date)
}
