#include <sourcemod>

public Plugin myinfo = {
    name = "[TF2] Dodgeball Stats",
    author = "keybangz",
    description = "A plugin with a web panel to display a global leaderboard on the server.",
    version = "1.0",
    url = ""
};

// we only need to remember the top speeds, who killed who & where the player places on the leaderboard.

// how we gonna get the stats from dodgeball plugin? idk but we gonna figure it out

/*

- dying will give players points based on cvar value, dying will lose points based on cvar value

organize leaderboard into percentages which allows for more competitive leaderboard pool, toggle by cvar

potentional:
create bot which records & uploads gameplay vs bot for highest speed on 1. individual profile or 2. top of server, 2 allows less space to be used on host ends 

*/

Database hDatabase = null;

ConVar g_cEnableDBStats;
ConVar g_cPointGain;
ConVar g_cPointLoss;
ConVar g_cSQLDatabase;

enum struct PlayerRank {
    char name[MAXPLAYERS+1];
    int points[MAXPLAYERS+1];
    int highestmph[MAXPLAYERS+1];
}

// should we be doing this on the global level? idk 
PlayerRank r;

public void OnPluginStart() {
    RegConsoleCmd("sm_rank", Command_CheckRank, "A command to check your rank on dodgeball.");

    g_cEnableDBStats = CreateConVar("sm_tf2stats_enable", "1", "Enable TF2 Dodgeball Stats?", _, true, 0.0, true, 1.0);
    g_cPointGain = CreateConVar("sm_tf2stats_pointgain", "2", "Amount of points to give to player when they kill someone?", _, true, 0.0, false);
    g_cPointLoss = CreateConVar("sm_tf2stats_pointloss", "2", "Amount of points for player to lose when they die", _, true, 0.0, false);
    g_cSQLDatabase = CreateConVar("sm_tf2stats_db", "leaderboard", "Name of the database connecting to store player data.", _, false, _, false, _);

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("arena_round_start", OnArenaRoundStart);

    StartSQL();
}

// implementing mysql based off wiki example
void StartSQL() {
    // created in memory on pluginload, in low level languages would i delete this or initialize it somewhere else? idk. 
    char dbname[64];

    // connect to db name set for databases.cfg
    g_cSQLDatabase.GetString(dbname, sizeof(dbname));

    Database.Connect(GotDatabase, dbname);
}

// connection callback
public void GotDatabase(Database db, const char[] error, any data) {
    if(db == null)
        LogError("Database failure: %s", error);

    hDatabase = db;

    char sQuery[256];

    hDatabase.Format(sQuery, sizeof(sQuery), "CREATE OR REPLACE TABLE leaderboard (name varchar(128) NOT NULL, steamid varchar(32))");
    hDatabase.Query(OnSQLConnect, sQuery);
}

public void OnSQLConnect(Database db, DBResultSet results, const char[] error, any data) {
    if(results == null) 
        LogError("Query failure: %s", error);
    
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i))
            OnClientPostAdminCheck(i);
    }
}

// grab steamid from client and check if they exist in the database
public void OnClientPostAdminCheck(int client) {
    char sSteamID[32];
    if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
        return;

    char sName[MAX_NAME_LENGTH];
    GetClientName(client, sName, sizeof(sName));

    char sQuery[256]; 
    hDatabase.Format(sQuery, sizeof(sQuery), "INSERT INTO onlineplayers(name, steamid) VALUES('%s', '%s')", sName, sSteamID);
    hDatabase.Query(CheckRank, sQuery);
}

public void CheckRank(Database db, DBResultSet results, const char[] error, any data) {
    if(results == null)
        LogError("Query failure", error); 
}

// commands

public void OnClientPutInServer(int client) {
    if(!g_cEnableDBStats.BoolValue)
        return;
        
    if(!IsClientInGame(client))
        return;

    // fetch and match details from mysql server
    r.points[client] = 0;
}

public Action Command_CheckRank(int client, int args) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    if(!IsClientInGame(client))
        return Plugin_Handled;

    if(args >> 0)
        return Plugin_Handled;

    // at this point we'll probably want to check when the db is connected to display stats.

    DrawRankMenu(client);

    // TODO:
    // we need to figure out what data we want to save, atm killing another person will give 2 points and that can represent people on a leaderboard.

    return Plugin_Handled;
}

public void DrawRankMenu(int client) {
    Menu menu = new Menu(RankLeaderboard_Handler, MENU_ACTIONS_ALL);

    char sPlayerName[64];

    Format(sPlayerName, sizeof(sPlayerName), "%N's Rank Board", client);

    menu.SetTitle(sPlayerName);

    char sPoints[64];

    Format(sPoints, sizeof(sPoints), "Points: %i", r.points[client]);

    menu.AddItem("", sPoints);
    menu.AddItem("", "Top Speed: `%f`");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}


// events

public int RankLeaderboard_Handler(Menu menu, MenuAction action, int param1, int param2) {
    switch(action) {
        case MenuAction_Select: {
            char info[24];
            GetMenuItem(menu, param2, info, sizeof(info));   
        }
    }

    return 0;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    int userid = event.GetInt("userid");
    int attacker = event.GetInt("attacker");

    if(!IsClientInGame(userid) || !IsClientInGame(attacker))
        return Plugin_Handled;

    if(IsFakeClient(userid) || IsFakeClient(attacker))
        return Plugin_Handled;

    if((r.points[attacker] || r.points[userid] <= 0))
        return Plugin_Handled;

    PrintToChat(userid, "[SM] You have lost %i points to %N.", g_cPointLoss.IntValue, attacker);
    PrintToChat(attacker, "[SM] You have gained %i points for killing %N.", g_cPointGain.IntValue, userid);

    r.points[attacker] = r.points[attacker] + g_cPointGain.IntValue;
    r.points[userid] = r.points[attacker] - g_cPointLoss.IntValue;

    return Plugin_Handled;
}

public Action OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    return Plugin_Handled;
}