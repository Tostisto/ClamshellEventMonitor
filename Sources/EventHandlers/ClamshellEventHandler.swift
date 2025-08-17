/// Protocol defining handlers for clamshell events
protocol ClamshellEventHandler {
    func onLidClosed()
    func onLidOpened()
}
