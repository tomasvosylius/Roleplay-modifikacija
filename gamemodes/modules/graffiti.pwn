#include <YSI\y_hooks>


#define DEFAULT_GRAFFITI_SIZE 		27

enum E_GRAFFITI_DATA
{
	graffitiId,
	graffitiObject,
	graffitiString[256],
	graffitiSize,
	graffitiInt,
	graffitiVW,
	Float:graffitiX,
	Float:graffitiY,
	Float:graffitiZ,
	Float:graffitiRX,
	Float:graffitiRY,
	Float:graffitiRZ
};
static 
	Graffiti[MAX_GRAFFITI][E_GRAFFITI_DATA];

static
	Iterator:Graffiti<MAX_GRAFFITI>;

static 
	player_GraffitiObject[MAX_PLAYERS],
	player_GraffitiString[MAX_PLAYERS][256],

	bool:player_Spraying[MAX_PLAYERS],
	bool:player_Started[MAX_PLAYERS],

	player_GraffitiFont[MAX_PLAYERS],
	player_Ammo[MAX_PLAYERS],
	player_UnsprayedTime[MAX_PLAYERS],
	player_SprayTimer[MAX_PLAYERS],
	player_SprayCount[MAX_PLAYERS];

static 
	graffiti_Fonts[][32] = {
		"Arial",
		"Comic Sans MS",
		"Impact"
};

flags:deletegraffiti(CMD_TYPE_ADMIN);
CMD:deletegraffiti(playerid, params[])
{
	foreach(new graffiti : Graffiti)
	{
		if(IsPlayerInRangeOfPoint(playerid, 10.0, Graffiti[graffiti][graffitiX], Graffiti[graffiti][graffitiY], Graffiti[graffiti][graffitiZ]))
		{
			if(IsValidDynamicObject(Graffiti[graffiti][graffitiObject])) DestroyDynamicObject(Graffiti[graffiti][graffitiObject]);

			new 
				string[126];
			mysql_format(chandler, string, sizeof string, "DELETE FROM `graffiti` WHERE id = '%d'", Graffiti[graffiti][graffitiId]);
			mysql_fquery(chandler, string, "GraffitiSaved");

			new 
				reset[E_GRAFFITI_DATA];
			Graffiti[graffiti] = reset;
			Graffiti[graffiti][graffitiObject] = -1;

			SendFormat(playerid, -1, "Artimiausias graffiti i�trintas!");
			Iter_Remove(Graffiti, graffiti);
			return 1;
		}
	}
	return 1;
}

flags:givegraffiti(CMD_TYPE_ADMIN);
CMD:givegraffiti(playerid, params[])
{
	new
		receiverid,
		amount;
	if(sscanf(params,"ud",receiverid, amount)) return SendUsage(playerid, "/givegraffiti [�aid�jas] [kiekis]");

	PlayerInfo[receiverid][pGraffitiAllowed] += amount;
	SaveAccountIntEx(receiverid, "GraffitiAllowed", PlayerInfo[receiverid][pGraffitiAllowed]);

	SendFormat(playerid, -1, "Dav�te �aid�jui graffiti leidim�: %d. I� viso turi: %d", amount, PlayerInfo[receiverid][pGraffitiAllowed]);
	SendFormat(receiverid, -1, "Gavote graffiti leidim�: %d. Turite: %d", amount, PlayerInfo[receiverid][pGraffitiAllowed]);
	return 1;
}

CMD:graffiti(playerid, params[])
{
	new 
		slot = sd_GetWeaponSlot(WEAPON_SPRAYCAN),
		weaponid,
		ammo;

	if(PlayerInfo[playerid][pGraffitiAllowed] <= 0) return SendWarning(playerid, "Neturite /graffiti leidimo. J� gauti galite i� administratoriaus.");
	if(player_Started[playerid] || IsValidDynamicObject(player_GraffitiObject[playerid])) return SendWarning(playerid, "J�s jau esate prad�j�s graffiti.");

	sd_GetPlayerWeaponData(playerid, slot, weaponid, ammo);
	if(weaponid != WEAPON_SPRAYCAN || GetPlayerWeapon(playerid) != WEAPON_SPRAYCAN) return SendWarning(playerid, "Rankose turite tur�ti Spray Can.");

	Dialog_Show(playerid, DialogInputGraffiti, DIALOG_STYLE_INPUT, "Graffiti", "{ffffff}�veskite tekst�, kur� norite i�pai�yti\n\nGalimos spalvos:\n{FF8B00}[�] {ffffff}(o) - oran�in�\n{5B3F01}[�] {ffffff}(br) - ruda\n{0000FF}[�] {ffffff}(bl) - m�lyna\n{000000}[�] {ffffff}(b) - juoda\n{008000}[�] {ffffff}(g) - �alia\n{FFFFFF}[�] {ffffff}(w) - balta\n{FFFF00}[�] {ffffff}(y) - geltona\n{FF0000}[�] {ffffff}(r) - raudona\n{800000}[�] {ffffff}(mr) - tamsiai raudona\n\n(n) - nauja eilute", "Prad�ti", "At�aukti");
	return 1;
}

Dialog:DialogInputGraffiti(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(strlen(inputtext) <= 3) return SendWarning(playerid, "Ne�ved�te teksto!");
		format(player_GraffitiString[playerid], 256, "%s", inputtext);
		new 
			string[256];
		for(new i = 0; i < sizeof graffiti_Fonts; i++)
		{
			format(string, sizeof string, "%s%s\n", string, graffiti_Fonts[i]);
		}
		Dialog_Show(playerid, DialogGraffitiFont, DIALOG_STYLE_LIST, "Graffiti �riftas", string, "T�sti", "At�aukti");
	}
	return 1;
}
Dialog:DialogGraffitiFont(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new 
			Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);
		player_GraffitiFont[playerid] = listitem;

		player_GraffitiObject[playerid] = CreateDynamicObject(18666, x + 2.0, y + 2.0, z + 0.5, 0.0, 0.0, 0.0, GetPlayerVirtualWorld(playerid), GetPlayerInterior(playerid), playerid);
		EditDynamicObject(playerid, player_GraffitiObject[playerid]);

		SendFormat(playerid, 0xd3dd00FF, "Nustatykite graffiti viet� (netoli j�s�).");
		SendFormat(playerid, 0xd3dd00FF, "Nustat� viet� gal�site u�baigti pie�im�.");

		PlayerInfo[playerid][pGraffitiAllowed] -- ;
	}
	return 1;
}

hook OnPlayerEditDynObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	new Float:oldx, Float:oldrx,
		Float:oldy, Float:oldry,
		Float:oldz, Float:oldrz;
	GetDynamicObjectPos(objectid, oldx, oldy, oldz);
	GetDynamicObjectRot(objectid, oldrx, oldry, oldrz);

	if(response == EDIT_RESPONSE_FINAL)
	{
		if(objectid == player_GraffitiObject[playerid] && player_GraffitiObject[playerid] != -1)
		{
			if(!IsPlayerInRangeOfPoint(playerid, 3.0, x, y, z))
			{
				SendError(playerid, "Graffiti pastat�te per toli nuo j�s�.");
				DestroyDynamicObject(player_GraffitiObject[playerid]);
				player_GraffitiObject[playerid] = -1;
				player_Started[playerid] = false;
				return 1;	
			}
			else
			{
				SendFormat(playerid, 0xd3dd00FF, "Nustat�te graffiti viet�. Pa�m� Spray Can pur�kite � objekt�.");
				SetTimerEx("T_GraffitiCheck", 7000, false, "d", playerid);
				SetTimerEx("T_Spray", 200, false, "d", playerid);

				SetDynamicObjectPos(objectid, x, y, z);
				SetDynamicObjectRot(objectid, rx, ry, rz);

				player_SprayCount[playerid] = 100;
			}
		}
	}
	return 1;
}

forward T_GraffitiCheck(playerid);
public T_GraffitiCheck(playerid)
{
	/* Reik tikrint ar isvis po to buvo padarytas tas graffiti */
	if(!player_Started[playerid] || (player_Started[playerid] && player_UnsprayedTime[playerid] >= 15))
	{
		if(IsValidDynamicObject(player_GraffitiObject[playerid]))
		{
			Graffiti_Reset(playerid);
			SendError(playerid, "Neprad�jote da�yti graffiti per 7 sekundes, tod�l veiksmas at�aukiamas.");
		}
	}
	return 1;
}

forward T_Spray(playerid);
public T_Spray(playerid)
{	
	new 
		Float:x, Float:y, Float:z,
		ammo = GetPlayerAmmo(playerid);

	GetDynamicObjectPos(player_GraffitiObject[playerid], x, y, z);
	if(IsPlayerSprayingAtPoint(playerid, x, y, z) && GetPlayerWeapon(playerid) == WEAPON_SPRAYCAN && player_Ammo[playerid] != ammo)
	{
		player_Ammo[playerid] = ammo;
		if(!player_Started[playerid]) player_Started[playerid] = true;
		if(player_UnsprayedTime[playerid] >= 0)
		{
			// Buvom ispeje, kad reik grizt. WB
			if(player_UnsprayedTime[playerid] >= 15)
			{
				SendFormat(playerid, 0xe8e8e8ff, "Gr��ote prie sprayinimo.");
			}
			player_UnsprayedTime[playerid] = 0;
		}
		// Nuimam count
		player_SprayCount[playerid] -= (3 + random(5));
		new 
			string[512],
			left = 100 - (player_SprayCount[playerid]);
		format(string, 46, "~r~]~w~ Dazymas: ~y~%d/100", left > 100 ? 100 : left);
		GameTextForPlayer(playerid, string, 3000, 3); 

		if(player_SprayCount[playerid] <= 0)
		{
			new 
				Float:rx, Float:ry, Float:rz;

			GetDynamicObjectRot(player_GraffitiObject[playerid], rx, ry, rz);

			if(IsValidDynamicObject(player_GraffitiObject[playerid])) DestroyDynamicObject(player_GraffitiObject[playerid]);
			player_GraffitiObject[playerid] = -1;

			strreplace(player_GraffitiString[playerid], "(n)", "\n");
			strreplace(player_GraffitiString[playerid], "(o)", "{FF8B00}");
			strreplace(player_GraffitiString[playerid], "(br)", "{5B3F01}");
			strreplace(player_GraffitiString[playerid], "(bl)", "{0000FF}");
			strreplace(player_GraffitiString[playerid], "(b)", "{000000}");
			strreplace(player_GraffitiString[playerid], "(g)", "{008000}");
			strreplace(player_GraffitiString[playerid], "(w)", "{FFFFFF}");
			strreplace(player_GraffitiString[playerid], "(y)", "{FFFF00}");
			strreplace(player_GraffitiString[playerid], "(r)", "{FF0000}");
			strreplace(player_GraffitiString[playerid], "(mr)", "{800000}");

			new slot = CreateGraffiti(player_GraffitiString[playerid], graffiti_Fonts[player_GraffitiFont[playerid]], DEFAULT_GRAFFITI_SIZE, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid), x, y, z, rx, ry, rz);

			Graffiti_Reset(playerid);
			SendFormat(playerid, 0x3bd631FF, "S�kmingai nupai��te graffiti.");

			mysql_format(chandler, string, sizeof string, "INSERT INTO `graffiti` (`Size`,`VW`,`Int`,`String`,`X`,`Y`,`Z`,`RX`,`RY`,`RZ`,`Valid`,`Font`,`AddedBy`) VALUES ('"#DEFAULT_GRAFFITI_SIZE"','%d','%d','%e','%f','%f','%f','%f','%f','%f','1','%d','%d')", GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid), player_GraffitiString[playerid], x, y, z, rx, ry, rz, player_GraffitiFont[playerid], PlayerInfo[playerid][pId]);
			mysql_tquery(chandler, string, "GraffitiAdded", "d", slot);
			return 1;
		}
	}
	else
	{
		if((player_UnsprayedTime[playerid]++) == 15)
		{
			// nesprayina kazkiek, vel tikrinsim. Jei negrizta cancel
			SendFormat(playerid, 0xc25a5aff, "Sustojote sprayinti. Turite gr��ti per 7 sekundes.");
			SetTimerEx("T_GraffitiCheck", 7000, false, "d", playerid);
		}
	}
	SetTimerEx("T_Spray", 200, false, "d", playerid);
	return 1;
}

forward GraffitiAdded(slot);
public GraffitiAdded(slot)
{	
	Graffiti[slot][graffitiId] = cache_insert_id();
	return 1;	
}		

thread(GraffitiSaved);


hook OnPlayerConnect(playerid)
{
	player_GraffitiObject[playerid] = -1;
	player_SprayTimer[playerid] = -1;
}

hook OnPlayerDisconnect(playerid, reason)
{
	if(IsValidDynamicObject(player_GraffitiObject[playerid])) DestroyDynamicObject(player_GraffitiObject[playerid]);
	player_GraffitiObject[playerid] = -1;

	if(player_SprayTimer[playerid] != -1) KillTimer(player_SprayTimer[playerid]);
	player_SprayTimer[playerid] = -1;
	return 1;
}

hook OnMysqlEstablished()
{
	mysql_tquery(chandler, "SELECT * FROM `graffiti` WHERE Valid = '1'", "OnGraffitiLoad", "");
	return 1;
}

forward OnGraffitiLoad();
public OnGraffitiLoad()
{
	printf("OnGraffitiLoad()");

	new 
		string[256],
		Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz,
		id, size, int, vw, font;

	for(new i = 0, rows = cache_num_rows(); i < rows; i++)
	{
		cache_get_value_name(i, "String", string);
		cache_get_value_name_int(i, "id", id);
		cache_get_value_name_int(i, "Size", size);
		cache_get_value_name_int(i, "VW", vw);
		cache_get_value_name_int(i, "Int", int);		
		cache_get_value_name_int(i, "Font", font);		
		cache_get_value_name_float(i, "X", x);
		cache_get_value_name_float(i, "Y", y);
		cache_get_value_name_float(i, "Z", z);
		cache_get_value_name_float(i, "RX", rx);
		cache_get_value_name_float(i, "RY", ry);
		cache_get_value_name_float(i, "RZ", rz);

		printf("Graffiti: %d [%d]", i, id);
		printf("%f, %f, %f\nString: %s", x, y, z, string);

		CreateGraffiti(string, graffiti_Fonts[font], size, int, vw, x, y, z, rx, ry, rz, .slot = i, .id = id);
	}
	return 1;
}

static stock CreateGraffiti(string[], font[], size, int, vw, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz, slot = -1, id = -1)
{
	if(slot == -1)
	{
		slot = Iter_Free(Graffiti);
	}


	Graffiti[slot][graffitiId] = id,
	Graffiti[slot][graffitiSize] = size,
	format(Graffiti[slot][graffitiString], 256, "%s", string);
	Graffiti[slot][graffitiX] = x,
	Graffiti[slot][graffitiY] = y,
	Graffiti[slot][graffitiZ] = z,
	Graffiti[slot][graffitiRX] = rx,
	Graffiti[slot][graffitiRY] = ry,
	Graffiti[slot][graffitiRZ] = rz;

	Graffiti[slot][graffitiVW] = vw;
	Graffiti[slot][graffitiInt] = int;

	Graffiti[slot][graffitiObject] = CreateDynamicObject(18666, x, y, z, rx, ry, rz, vw, int, -1);
	SetDynamicObjectMaterialText(Graffiti[slot][graffitiObject], 0, string, OBJECT_MATERIAL_SIZE_256x256, font, size, 1, 0xFFFFFFFF, 0, 1);

	Iter_Add(Graffiti, slot);
	return slot;
}

stock Graffiti_Reset(playerid)
{
	if(player_SprayTimer[playerid] != -1) KillTimer(player_SprayTimer[playerid]);
	player_SprayTimer[playerid] = -1;

	if(IsValidDynamicObject(player_GraffitiObject[playerid])) DestroyDynamicObject(player_GraffitiObject[playerid]);
	player_Spraying[playerid] = false;
	player_Started[playerid] = false;
	player_GraffitiObject[playerid] = -1;
	return 1;
}


stock IsPlayerSprayingAtPoint(playerid, Float:x, Float:y, Float:z)
{
	new
	    player_index = GetPlayerAnimationIndex(playerid),
		Float:player_x,
		Float:player_y,
		Float:player_z,
		Float:player_a;

	GetPlayerPos(playerid, player_x, player_y, player_z);
	GetPlayerFacingAngle(playerid, player_a);

	player_x += 2.0 * floatsin(-player_a, degrees);
	player_y += 2.0 * floatcos(-player_a, degrees);

	if(IsObjectInRangeOfPoint(x, y, z, 3.0, player_x, player_y, player_z))
	{
		return (1160 <= player_index <= 1163) || player_index == 1167 || player_index == 640;
	}
	return 0;
}
stock IsObjectInRangeOfPoint(Float:obj_x, Float:obj_y, Float:obj_z, Float:range, Float:point_x, Float:point_y, Float:point_z)
{
	obj_x -= point_x;
	obj_y -= point_y;
	obj_z -= point_z;
	return ((obj_x * obj_x) + (obj_y * obj_y) + (obj_z * obj_z)) < (range * range);
}