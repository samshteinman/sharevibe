# ShareVibe

Bluetooth Radio Station

Stream song from iTunes library over BLE

Listeners subscribe to your iPhone and hear the songs you pick

Launch app on both

One of them chooses "Listen"

Another chooses "Broadcast" and picks the song(low quality MP4, the only one that can support streaming over BLE at 32kbps)

After ~65k bytes are sent, music starts on both phones

TODO:

1. Chatroom

2. Be able to use songs in the cloud

3. Listeners can't join in the middle of a song(currently using AVPlayer, will need to learn about Audio Queue Services)

4. Instructions page?
