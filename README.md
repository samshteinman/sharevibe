# ShareVibe

Bluetooth Radio Station

Stream song from iTunes library over BLE

Listeners subscribe to your iPhone and hear the songs you pick

Launch app on both

One of them chooses "Listen"

Another chooses "Broadcast" and picks the song(low quality MP4, the only one that can support streaming over BLE at 32kbps)

After ~65k bytes are sent, music starts on both phones

TODO:
Chatroom?

Listeners can't join in the middle of a song(currently using AVPLayer, will need to learn about Audio Queue Services)
