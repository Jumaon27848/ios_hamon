import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class HEventQueue {
  
  private let queue = DispatchQueue(label: "com.hamon.eventqueue", qos: .utility)
  private var events: [HAnalyticsEvent] = []
  private var firstEventTimestamp: Date?
  private var flushTimer: Timer?
  
  private let maxEventsBeforeFlush = 10
  private let maxTimeBeforeFlush: TimeInterval = 10.0
  
  var onFlush: (([HAnalyticsEvent]) -> Void)?
  
  init() {
    setupTimer()
    setupBackgroundObservers()
  }
  
  deinit {
    flushTimer?.invalidate()
    NotificationCenter.default.removeObserver(self)
  }
  
  // MARK: - Public Methods
  
  func add(event: HAnalyticsEvent) {
    queue.async { [weak self] in
      guard let self = self else { return }
      
      self.events.append(event)
      
      if self.firstEventTimestamp == nil {
        self.firstEventTimestamp = Date()
      }
      
      if self.events.count >= self.maxEventsBeforeFlush {
        self.flush()
      }
    }
  }
  
  func flush() {
    queue.async { [weak self] in
      guard let self = self else { return }
      
      guard !self.events.isEmpty else { return }
      
      let eventsToSend = self.events
      self.events.removeAll()
      self.firstEventTimestamp = nil
      
      DispatchQueue.main.async {
        self.onFlush?(eventsToSend)
      }
    }
  }
  
  func clear() {
    queue.async { [weak self] in
      self?.events.removeAll()
      self?.firstEventTimestamp = nil
    }
  }
  
  // MARK: - Private Methods
  
  private func setupTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.flushTimer = Timer.scheduledTimer(
        withTimeInterval: 1.0,
        repeats: true
      ) { [weak self] _ in
        self?.checkTimeBasedFlush()
      }
    }
  }
  
  private func checkTimeBasedFlush() {
    queue.async { [weak self] in
      guard let self = self,
            let firstTimestamp = self.firstEventTimestamp else {
        return
      }
      
      let elapsed = Date().timeIntervalSince(firstTimestamp)
      if elapsed >= self.maxTimeBeforeFlush {
        self.flush()
      }
    }
  }
  
  private func setupBackgroundObservers() {
#if canImport(UIKit)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillTerminate),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
#endif
  }
  
  @objc private func appDidEnterBackground() {
    flush()
  }
  
  @objc private func appWillTerminate() {
    flush()
  }
}

extension HEventQueue {
  /// Drains events and flushes queue
  func drain() -> [HAnalyticsEvent] {
    var drainedEvents: [HAnalyticsEvent] = []
    queue.sync {
      drainedEvents = events
      events.removeAll()
      firstEventTimestamp = nil
    }
    return drainedEvents
  }
  
  /// Adds few events back to queue
  func add(events newEvents: [HAnalyticsEvent]) {
    queue.async { [weak self] in
      self?.events.append(contentsOf: newEvents)
      if self?.firstEventTimestamp == nil {
        self?.firstEventTimestamp = Date()
      }
    }
  }
}
