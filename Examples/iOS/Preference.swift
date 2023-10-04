struct Preference {
    static var defaultInstance = Preference()

    var uri: String? = "rtmp://streamer4.rolla.app/rc/"
    var streamName: String? = "test"
}
