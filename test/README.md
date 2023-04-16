Configure tests:
1. Create my_test1_bot and my_test2_bot with https://t.me/BotFather
2. Create test.credentials file with content:
```token-1 <auth token for my_test1_bot>
token-2 <auth token for my_test2_bot>```
3. Set bot privacy in BotFather
    * enter command /setprivacy
    * choose my_test1_bot
    * choose Disable
    * repeat for my_test2_bot
4. Create a channel ( Menu -> New Channel )
5. Specify a channel name as "tcltelegram"
6. Invite the bots to the channel (as admins).
    * go to Channel Info -> add member
    * add there https://t.me/my_test1_bot
    * add there https://t.me/my_test2_bot
