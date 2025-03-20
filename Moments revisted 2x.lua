-- Moments Tracker Revisited, an extension for VLC, to store your moments
-- 2025a
------------------------------------------------
-- Global variables
minsec_display=1
 -- 1  xx:xx:xx hours:minutes:seconds (default)
 -- 0  xxx per thousands of medium duration
vlc_version=1
-- 0 reads VLC version in vlcrc settings file (default)
-- 4 enforces VLC version 4
medium_name_predefined="??"
-- "??" starts with Media management (default)
-- "" takes VLC detected medium name directly to the Moments window (to Media magt if no medium playing)
maxtrainer=300      -- nr of elements to "train" the tmsorted table of displayed lists
mshow_list={}
table_save_lmed={}
table_save_lmom={}
tnames={}
nmeds=0
selected_med=""
main_layout=nil
enter_text_label=nil
caption_text_input=nil
confirm_capted=nil
err_label=nil
info_med1=nil
info_med2=nil
simodif=false
bokmed=false
printd=true
capencours=false
affinfomed=false
affreverse=false
afferr=false
medium_name=""
medium_uri=""
badloop=0
mediumidx=0
nmoms=0
dectomomname=0
currmom=0
currmomch=""
tmomname={}
tmompos={}
tmomch={}
tmomem={}
tmsorted={}
checkpoint_l=nil
imp_button=nil
check_xspf=nil
checkpos=0
checkposch=""
checktimech=""
checkch=""
destination=""
tdur=0

function descriptor()
  return {
  title = "Moments Tracker Revisited",
  version = "2025a",
  author = "A Rashed + jpcare", -- original design and coding by ARahman Rashed, reworked & extended by JP Carillon
  url = 'https://addons.videolan.org/p/1848670',
  shortdesc = "Bookmark Moments",
  description = "",
  capabilities = {"menu", "input-listener", "meta-listener", "playing-listener"}
  }
end

function checkversion()  -- VLC 3 misc.version() crashes
  local file
  local vlconf
  local chcar
  local chcarsup
  local versionlue
  local k,kf
  vlconf=vlc.config.configdir().."/vlcrc"
  file=io.open(vlconf)
  if file then
    for line in file:lines() do
      if line then
        k,kf=string.find(line,"###  vlc %d")
        if k==1 then
          chcar=string.sub(line,10,10)
          if (#(line)>10) then
            chcarsup=string.sub(line,11,11)
            if tonumber(chcarsup) then chcar=chcar..chcarsup end
          end
          versionlue=tonumber(chcar)
          if versionlue then
            if versionlue<4 then
              if vlc_version<4 then vlc_version=0
              else vlc_version=4 end
            else vlc_version=4 end
          end
          break
        end
      else break end
    end
    file:close()
  end
end

function get_basic_data()
  if vlc_version<4 then
    input=vlc.object.input()
    medium_name=vlc.input.item():name()
    medium_uri=vlc.input.item():uri()
   -- no metas for track in DVD
    tdur=vlc.input.item():duration()
   else
    player=vlc.object.player()
    medium_name=vlc.player.item():name()
    medium_uri=vlc.player.item():uri()
    tdur=vlc.player.item():duration()
  end
end

function display_impossible()
  error_dialog=vlc.dialog("Cannot use this medium")
  error_dialog:add_label("Please : no external stream, no improper name")
end

function display_badfile()
  error_dialog=vlc.dialog("Data corruption")
  error_dialog:add_label("Your moments_tracker.txt database cannot be used")
  error_dialog:add_label("Bad line ["..badloop.."] in file")
end

function kwickfileok()
  local filepass=true
  local file=io.open(destination)
  if file then
    local balance=true
    local k,kf
    local ntilde
    badloop=-1
    for line in file:lines() do
      if balance then  -- medium line
        badloop=badloop+2
        filepass=false
        k,kf=string.find(line,"~")
        if k>1 then
          ntilde=0
          for w in string.gmatch(line,"~") do ntilde=ntilde+1 end
          if ntilde==3 then -- 3 fields exactly
            if not(string.find(line,"*&",k)) then filepass=true end -- no mix with moments
          end
        end
      end
      if filepass then balance=not(balance)
      else break end
    end
    file:close()
  end
  if filepass then badloop=0 end
  return filepass
end

function checkmedium()
  bokmed=pcall(get_basic_data)
  if bokmed then
    if not(tdur>0) or (#(corename(medium_name))<1) then
      bokmed=false
      display_impossible()
    else
      medium_name=string.gsub(medium_name,"~","_")
    end
  end
end

function activate()
  destination=vlc.config.userdatadir().."/moments_tracker.txt"
  if not(kwickfileok()) then
    display_badfile()
    return 0
  end
  simodif=false
  checkversion()
  checkmedium()
  if minsec_display>0 then dectomomname=10
  else dectomomname=5 end
  load_media_tables()
  if not(bokmed) or (medium_name_predefined=="??") then
    MediaGUI()
  else
    ToMomentsGUI(0)
  end
end

function close()
  if capencours then exitpause() end
  vlc.deactivate()
end

function deactivate()
  save_database()
end

function save_database()
  if simodif then  -- rewrite full database
    simodif=false
    local temp=destination.."_copy"..os.date("%Y%m%d%H%M%S")
    local bos=os.rename(destination,temp)
    local file=io.open(destination,"w+")
    local i=0
    local nullfound=false
    while i<nmeds do
     i=i+1
     if #(tnames[i])>0 then
       file:write(table_save_lmed[i],"\n",table_save_lmom[i],"\n")
     else
       nullfound=true
     end
    end
    file:flush()
    file:close()
    if bos then bos=os.remove(temp) end
    if nullfound then -- log removed media
      local dest,sint
      local ch=""
      local iend,kf
      i=0
      while i<nmeds do
        i=i+1
        if #(tnames[i])==0 then
          sint=table_save_lmed[i]
          if #(sint)>0 then
            if #(ch)==0 then
              dest=vlc.config.userdatadir().."/moments_tracker_deletelog.txt"
              file=io.open(dest,"a+")
              file:seek("end")
              file:write(os.date("%Y/%m/%d %H:%M").."\n")
            end
            iend,kf=string.find(sint,"~")
            iend=iend-1
            ch=string.sub(sint,1,iend)
            iend=iend+1
            ch=ch..os.date("%Y%m%d%H%M%S")..string.sub(sint,iend)
            file:write(ch,"\n",table_save_lmom[i],"\n","================\n")
            table_save_lmed[i]=""
          end
        end
      end
      if #(ch)>0 then
        file:flush()
        file:close()
      end
    end
  end
end

function load_media_tables()
-- Loads moments_tracker.txt database into tables
-- Database : 2 lines per medium
-- line 1 medium_name ~ checkpoint data
-- line 2 nil or list of moments
  local balance=true
  local sint=""
  local k,kf
  local file
  nmeds=0
  file=io.open(destination)
  if file then
    for line in file:lines() do
      if balance then
        k,kf=string.find(line,"~")
        sint=string.sub(line,1,(k-1))
        nmeds=nmeds+1
        tnames[nmeds]=sint
        table_save_lmed[nmeds]=line
        table_save_lmom[nmeds]=""
      else
        table_save_lmom[nmeds]=line
      end
      balance=not(balance)
    end
    file:close()
  end
  k=0
  while k<maxtrainer do
   k=k+1
   rawset(tmsorted,k," "..k)
  end
  while k>0 do
    sint=table.remove(tmsorted)
    k=k-1
  end
end

function check_medium_name()
  local sint=medium_name_predefined
  sint=corename(sint)
  if #(sint)>1 then
    if not(string.find(sint,"~")) then
      medium_name_predefined=sint
      return 1
    end
  end
  return 0
end

function killblanks(chin)
  local sout=""
  local len=#(chin)
  local i=0
  while i<len do
    i=i+1
    if string.sub(chin,i,i)~=" " then
      sout=string.sub(chin,i,len)
      break
    end
  end
  return sout
end

function corename(inchin) -- extra blanks
  local sout=inchin
  if #(sout)>0 then sout=killblanks(sout) end
  if #(sout)>0 then sout=killblanks(string.reverse(sout)) end
  if #(sout)>1 then sout=string.reverse(sout) end
  return sout
end

function select_nop()
end

function cleanerr()
  if afferr then
     main_layout:del_widget(err_label)
     afferr=false
  end
end

function cleaninfomed()
  if affinfomed then
    main_layout:del_widget(info_med2)
    main_layout:del_widget(info_med1)
    affinfomed=false
  end
end

function oneselected(koko)
  cleanerr()
  local selexam=mshow_list:get_selection()
  if selexam then
    local tidx=0  
    local ifirst=true
    local selec=nil
    for idx,selectedItem in pairs(selexam) do
      tidx=idx
      if ifirst then
        selec=selectedItem
        ifirst=false
      else
        selec=nil
        break
      end
    end
    if not(selec) then
      if koko>0 then showkerr(7) end
    end
    return selec,tidx
  else
    return nil,0
  end
end

function select_med_exit()
  if capencours then return end
  ToMomentsGUI(1)
end

function select_med_line()
  if capencours then return end
  local sel,ri
  sel,ri=oneselected(1)
  if not(sel) then return end
  medium_name=sel
  ToMomentsGUI(1)
end

function capture_med()
  if capencours then return end
  capencours=true
  local chint,ri
  chint,ri=oneselected(0)
  if not(chint) then
    chint=""
  end
  if #(chint)==0 and #(medium_name)>0 then chint=medium_name end
  enter_text_label=main_layout:add_label("<b><i>NEW medium name </i></b>  --->",1,2,1)
  caption_text_input=main_layout:add_text_input(chint,2,2,5)
  confirm_capted=main_layout:add_button("OK",confirm_med,7,2,1)
end

function confirm_med()
  local caption_text
  cleanerr()
  caption_text=caption_text_input:get_text()
  if caption_text==nil then caption_text="  " end
  if #(caption_text)==0 then caption_text="  " end
  medium_name_predefined=caption_text
  local rcheck=check_medium_name()
  main_layout:del_widget(enter_text_label)
  main_layout:del_widget(caption_text_input)
  main_layout:del_widget(confirm_capted)
  if rcheck<1 then
    capencours=false
    showkerr(1)
  else
    medium_name=medium_name_predefined
    ToMomentsGUI(1)
  end
end

function confirm_changemed()
  local caption_text
  cleanerr()
  caption_text=caption_text_input:get_text()
  if caption_text==nil then caption_text="  " end
  if #(caption_text)==0 then caption_text="  " end
  medium_name_predefined=caption_text
  local recheck=check_medium_name()
  caption_text=medium_name_predefined
  main_layout:del_widget(enter_text_label)
  main_layout:del_widget(caption_text_input)
  main_layout:del_widget(confirm_capted)
  if recheck<1 then
    showkerr(1)
    capencours=false
    return
  end
  if caption_text==selected_med then capencours=false return 1 end
  if findia(caption_text)>0 then
    capencours=false
    err_label=main_layout:add_label("<b><font color=darkred>This medium name already exists !</font></b>",1,2,3)
    afferr=true
    return
  end
  local k,kf
  local i=findia(selected_med)
  if i>0 then
    local lineref=table_save_lmed[i]
    k,kf=string.find(lineref,"~")
    lineref=caption_text..string.sub(lineref,k)
    table_save_lmed[i]=lineref
    tnames[i]=caption_text
    simodif=true
    display_media_names()
  end
  capencours=false
end

function dup_med_line()
  if capencours then return end
  local sel,ri
  sel,ri=oneselected(1)
  if not(sel) then return end
  local i=findia(sel)
  if i>0 then
   local dupname=sel..os.date("%Y%m%d%H%M%S")
   nmeds=nmeds+1
   tnames[nmeds]=dupname
   lineref=table_save_lmed[i]
   local shnt=string.reverse(lineref)
   k,kf=string.find(shnt,"~")
   shnt=string.sub(shnt,k)
   lineref=string.reverse(shnt)..os.date("%Y/%m/%d")
   k,kf=string.find(lineref,"~")
   lineref=dupname..string.sub(lineref,k)
   table_save_lmed[nmeds]=lineref
   table_save_lmom[nmeds]=table_save_lmom[i]
   simodif=true
   display_media_names()
  end
end

function remove_med_line()
  if capencours then return end
  local sel,ri
  sel,ri=oneselected(1)
  if not(sel) then return end
  cleaninfomed()
  local i=findia(sel)
  if i>0 then
   tnames[i]=""
   simodif=true
   local s=table.remove(tmsorted)
   display_media_names()
  end
end

function change_med_line()
  if capencours then return end
  capencours=true
  local sel,ri
  sel,ri=oneselected(1)
  if not(sel) then capencours=false return end
  selected_med=sel
  if bokmed then
  enter_text_label=main_layout:add_label("<b><i>SUBSTITUTE name </i></b>   --->",1,2,1)
  caption_text_input=main_layout:add_text_input(sel,2,2,5)
  else
  enter_text_label=main_layout:add_label("<b><i>SUBSTITUTE name </i></b>   --->",1,2,2)
  caption_text_input=main_layout:add_text_input(sel,3,2,4)
  end
  confirm_capted=main_layout:add_button("OK",confirm_changemed,7,2,1)
end

function info_med_line()
  local sel,ri
  sel,ri=oneselected(1)
  if not(sel) then return end
  local ient=findia(sel)
  if ient==0 then return end
  cleaninfomed()
  local sline=table_save_lmed[ient]
  local infodate=""
  local infopoint=""
  local cna="NA"
  for ch0,v,ch1,ch2 in string.gmatch(sline,"(.+)~(.+)~(.+)~(.+)") do
    infopoint=ch1
    infodate=ch2
  end
  if #(infodate)==0 then infodate=cna
  else -- obsolete content
    if tonumber(string.sub(infodate,1,1))==nil then infodate=cna end
    if string.find(infodate,":") then infodate=cna end
  end
  if #(infopoint)==0 then infopoint=cna
  else
    local i,kf
    i,kf=string.find(infopoint," ")
    if i then
      if i>1 then infopoint=string.sub(infopoint,1,(i-1)) end
    end
  end
  local infomom=0
  sline=table_save_lmom[ient]
  if sline then
    for w in string.gmatch(sline,"*&") do
      infomom=infomom+1
    end
  end
  local aff="<b><i>"..sel.."</i></b>"
  info_med1=main_layout:add_label(aff,1,9,7)
  aff=os.date("%Y/%m/%d")
  if infopoint==aff then infopoint="today" end
  if infodate==aff then infodate="today" end
aff="<i>Nr of stored moments ["..infomom.."] Medium ["..infodate.."] Checkpoint ["..infopoint.."]</i>"
  info_med2=main_layout:add_label(aff,1,10,7)
  affinfomed=true
end

function display_media_names()
  local k=0
  local kaff=0
  while k<nmeds do
    k=k+1
    if #(tnames[k])>0 then
      kaff=kaff+1
      rawset(tmsorted,kaff,tnames[k])
    end
  end
  if kaff>1 then
   table.sort(tmsorted)
  end
  k=0
  mshow_list:clear()
  while k<kaff do
    k=k+1
    mshow_list:add_value(tmsorted[k],k)
  end
end

function MediaGUI()
  capencours=false
  affinfomed=false
  afferr=false
  main_layout=vlc.dialog("Media management")
  main_layout:add_label(" ",1,2)
  main_layout:add_label("<b>List of <font color=darkred>MEDIA names</font></b> in database",1,3,7)
  main_layout:add_button("",select_nop,1,5,1)  --ghost default
  if bokmed then
    main_layout:add_button("Start with VLC detected name ",select_med_exit,1,5,1)
    main_layout:add_button("Start with selected name ",select_med_line,2,5,1)
    main_layout:add_button(" Start with a new name ",capture_med,3,5,1)
  else
    main_layout:add_button("NOP",select_nop,1,5,1)
    main_layout:add_button("NOP",select_nop,2,5,1)
    main_layout:add_button("NOP",select_nop,3,5,1)
  end
  main_layout:add_button(" Info/selected ",info_med_line,4,5,1)
  main_layout:add_button(" Rename selected ",change_med_line,5,5,1)
  main_layout:add_button(" Duplicate selected ",dup_med_line,6,5,1)
  main_layout:add_button(" Delete selected ",remove_med_line,7,5,1)
  main_layout:add_label("<hr>",1,6,7)
  if bokmed then
    local duree
    if minsec_display>0 then
      duree=formatpos(1)
    else
      minsec_display=1
      duree=formatpos(1)
      minsec_display=0
    end
    main_layout:add_label("<font color=darkred>VLC detected ["..duree.."]</font> : "..medium_name,1,7,7,1)
  else
    main_layout:add_label("<font color=darkred>No playing medium</font>",1,7,7)
  end
  main_layout:add_label("<hr>",1,8,7)
  mshow_list=main_layout:add_list(1,4,7)
  main_layout:show()
  display_media_names()
end

function ToMomentsGUI(medwin)
  if medwin>0 then
    cleanerr()
    cleaninfomed()
    main_layout:delete()
    save_database()
    local k=#(tmsorted)
    local s
    while k>0 do
      s=table.remove(tmsorted)
      k=k-1
    end
  end
  load_medium_data()
  MomentsGUI()
end

function MomentsGUI()
   capencours=false
   affreverse=false
   afferr=false
   printd=true
   currmom=0
   main_layout=vlc.dialog("Moments & checkpoint")
   main_layout:add_label(" ",1,2)
   main_layout:add_label("<b>Moments in current medium </b>",1,3,2)
   main_layout:add_label("<i>(close/restart the extension at will)</i>",3,3,2)
   main_layout:add_button("",select_nop,1,5,1) --ghost default
   main_layout:add_button(" Capture Moment ",capture_moment,1,5,1)
   main_layout:add_button(" Jump to Moment ",jump_to_moment,2,5,1)
   main_layout:add_button(" Remove Moment ",remove_moment,3,5,1)
   main_layout:add_button(" Reverse List ",antilist,4,5,1)
   info_med2=main_layout:add_label(" ",1,6,4)
   main_layout:add_label("<hr>",1,7,4)
   main_layout:add_label("<font color=darkblue><b>Recorded Checkpoint : </b></font>",1,8,1)
   checkpoint_l=main_layout:add_label("",2,8,2)
   display_checkpoint_data()
   main_layout:add_button("Checkpoint  !",mark_position,1,9,1)
   main_layout:add_button(" Jump to Checkpoint ",jump_to_checkpoint,2,9,1)
   main_layout:add_button(" [MEDIA] ",back_tomedia,4,9,1)
   main_layout:add_label("<font color=darkred>Medium name</font> : ".. medium_name,1,10,4,1)
   mshow_list=main_layout:add_list(1,4,4)
   main_layout:show()
   display_moments(2)
end

function display_checkpoint_data()
  if #(checkposch)>0 then
    checkpoint_l:set_text("<i>"..checktimech.."</i> >>><font color=darkblue><b>"..checkposch.."</b></font>")
  else
    checkpoint_l:set_text("<i> No checkpoint marked for this medium</i>")
  end
end

function remindin()
  enter_text_label:set_text("<b><u><font color=darkred>Name New Moment</font></u></b> ---->")
end

function back_tomedia()
  if capencours then
    remindin()
    return
  end
  cleanerr()
  if check_xspf then main_layout:del_widget(check_xspf) end
  if imp_button then main_layout:del_widget(imp_button) end
  main_layout:delete()
  checkmedium()
  local k=nmoms
  local s
  while k>0 do
    s=table.remove(tmsorted)
    k=k-1
  end
  MediaGUI()
end

function save_checkpoint()
  if mediumidx<1 then  -- new medium entry
    nmeds=nmeds+1
    mediumidx=nmeds
    tnames[nmeds]=medium_name
    checkch=os.date("%Y/%m/%d")
  end
  table_save_lmed[mediumidx]=medium_name.."~"..checkpos.."~"..checktimech.."~"..checkch
  if nmoms<1 then
    table_save_lmom[mediumidx]="nil"
  end
  simodif=true
  display_checkpoint_data()
end

function findia(sme)
  local chn=sme
  local i=nmeds
  while i>0 do
    if rawequal(chn,tnames[i]) then break end
    i=i-1
  end
  return i
end

function load_medium_data()
-- Checkpoint and moments of current medium
  local linem,chunk,cha,chb
  local ideb,ifound,idf,ik,len
  local pom
  mediumidx=0
  nmoms=0
  checkposch=""
  if nmeds==0 then return end
  mediumidx=findia(medium_name)
  if mediumidx==0 then return end
  linem=table_save_lmed[mediumidx]
  ideb,idf=string.find(linem,"~")
  ideb=ideb+1
  ik,idf=string.find(linem,"~",ideb)
  checkpos=torealnum(string.sub(linem,ideb,(ik-1)))
  checkposch=formatpos(checkpos)
  ideb=ik+1
  ik,idf=string.find(linem,"~",ideb)
  checktimech=string.sub(linem,ideb,(ik-1))
  checkch=string.sub(linem,(ik+1))
  linem=table_save_lmom[mediumidx]
  ifound,idf=string.find(linem,"*&")
  ideb=1
  len=#linem-2
  while ifound do
    chunk=string.sub(linem,ideb,(ifound-1))
    ideb=ifound+2
    ik,idf=string.find(chunk,"~")
    if ik then
      cha=string.sub(chunk,1,(ik-1))
      if #cha>0 then
        chb=string.sub(chunk,(ik+1))
        nmoms=nmoms+1
        tmomem[nmoms]=chunk.."*&"
        tmomname[nmoms]=cha
        pom=torealnum(chb)
        tmompos[nmoms]=pom
        tmomch[nmoms]=formatpos(pom).." "..cha
      end
    end
    if ideb<len then
      ifound,idf=string.find(linem,"*&",ideb)
    else break end
  end
end

function torealnum(vv)
  local rnum
  if #(vv)>=8 then -- 6 digits fraction unit < 1 s in 100 H
     rnum=tonumber(string.sub(vv,3,8))
     if rnum then
       return (rnum * 0.000001)
     else return 0 end
  end
  local lenv=#(vv)
  if lenv>2 then
    if string.sub(vv,1,1)=="0" then
       rnum=tonumber(string.sub(vv,3,lenv))
       if rnum then
         return (rnum/ (math.pow(10,(lenv-2))))
       else return 0 end
    else
      if string.sub(vv,1,1)=="1" then return 1 end
    end
  else
    if string.sub(vv,1,1)=="1" then return 1 end
  end
  return 0
end

function tostraff2(n2d)   -- tostring 2 d
  local nd,nu
  nu=n2d % 10
  nd=(n2d-nu)/10
return string.char((nd+48),(nu+48))
end

function tostraff3(n3d)   -- tostring 3 d
  local ntop,nu,nd,nc
  nu=n3d % 10
  ntop=(n3d-nu) / 10
  nd=ntop % 10
  nc=(ntop-nd) / 10
return string.char((nc+48),(nd+48),(nu+48))
end

function formatpos(position)
  if minsec_display>0 then
     local grandm
     local totsec=tdur*position
     local grandh=math.floor(totsec/3600)
     local restsec=totsec-(3600*grandh)
     if restsec<0 then restsec=0 end
     if grandh>=100 then
       return "::::::::"
     else
       grandm=math.floor(restsec/60)
       restsec=restsec-(60*grandm)
       if restsec<0 then restsec=0 end
       restsec=math.floor(restsec)
       return tostraff2(grandh)..":"..tostraff2(grandm)..":"..tostraff2(restsec)
     end
  else
    local pourmil=math.floor(position*1000+0.5)
    if pourmil>=1000 then pourmil=999 end
    return tostraff3(pourmil)
  end
end

function mark_position()
  if capencours then
    remindin()
    return
  end
  if vlc_version<4 then
    checkpos=vlc.var.get(input,"position")
  else
    checkpos=vlc.player.get_position()
  end
  checkposch=formatpos(checkpos)
  checktimech=os.date("%Y/%m/%d %H:%M:%S")
  save_checkpoint()
  exitpause()
  cleanerr()
end

function exitpause()
  if not(vlc.playlist.status()=="playing") then
    vlc.playlist.pause()  -- toggle
  end
end

function jump_to_checkpoint()
  if capencours then
    remindin()
    return
  end
  exitpause()
  if #(checkposch)>0 then
    if vlc_version<4 then
      vlc.var.set(input,"position",checkpos)
    else
      vlc.player.seek_by_pos_absolute(checkpos)
    end
  end
  cleanerr()
end

function capture_moment()
  if capencours then
    remindin()
    return
  end
  capencours=true
  local sint,ri
  sint,ri=oneselected(0)
  if sint then
    sint=string.sub(sint,dectomomname)   
  else sint=""  end
  if vlc.playlist.status()=="playing" then
    vlc.playlist.pause()
  end
  enter_text_label=main_layout:add_label("<b><i>Name New Moment</i></b> ---->",1,2,1)
  caption_text_input=main_layout:add_text_input(sint,2,2,2)
  confirm_capted=main_layout:add_button("SAVE IT",confirm_caption,4,2,1)
end

function confirm_caption()
  local caption_text
  local bad=true
  local mombeg
  caption_text=caption_text_input:get_text()
  if caption_text==nil then
    caption_text=" "
  end
  if string.find(caption_text,"*&") or string.find(caption_text,"~") then
    caption_text=" "
  end
  main_layout:del_widget(enter_text_label)
  main_layout:del_widget(caption_text_input)
  main_layout:del_widget(confirm_capted)
  if #(caption_text)>1 then
    bad=false
    if vlc_version<4 then
      mombeg=vlc.var.get(input,"position")
    else
      mombeg=vlc.player.get_position()
    end
    if not(mombeg) then
      mombeg=0
    end
    local sint=formatpos(mombeg)
    if #(checkposch)==0 then
      checkpos=mombeg
      checkposch=sint
      checktimech=os.date("%Y/%m/%d %H:%M:%S")
      save_checkpoint()
    end
    nmoms=nmoms+1
    tmomname[nmoms]=caption_text
    tmompos[nmoms]=mombeg
    tmomch[nmoms]=sint.." "..caption_text
    sint=caption_text.."~"..mombeg.."*&"
    tmomem[nmoms]=sint
    if nmoms==1 then
      table_save_lmom[mediumidx]=sint
    else
      table_save_lmom[mediumidx]=table_save_lmom[mediumidx]..sint
    end
    simodif=true
  end
  if bad then
    showkerr(2)
  else
    display_moments(2)
  end
  capencours=false
  exitpause()
end

function display_moments(ksor)
  local k=0
  if ksor>0 then
    while k<nmoms do
      k=k+1
      rawset(tmsorted,k,tmomch[k])
    end
    if nmoms>1 then
      table.sort(tmsorted)
      if (ksor==2) and (currmom>0) then
        if not rawequal(string.sub(tmsorted[currmom],1,dectomomname),currmomch) then
          currmom=currmom+1
        end
      end
    end
  end
  mshow_list:clear()
  if affreverse then
    k=nmoms
    while k>0 do
      mshow_list:add_value(tmsorted[k],k)
      k=k-1
    end
  else
    k=0
    while k<nmoms do
      k=k+1
      mshow_list:add_value(tmsorted[k],k)
    end
  end
  if printd and (ksor>0) then
    local kf
    printd=false
    imp_button=main_layout:add_button(" Export Moments ",memosave,1,11,4)
    k,kf=string.find(medium_uri,"file:///")
    if k==1 then check_xspf=main_layout:add_check_box("playlist ",false,4,11,1)
    else check_xspf=nil end
  end
end

function antilist()
  cleanerr()
  affreverse=not(affreverse)
  display_moments(0)
end

function findmo(smo)
 local chn=smo
 local icher=nmoms
 while icher>0 do
   if rawequal(chn,tmomch[icher]) then
     break
   end
   icher=icher-1
 end
 return icher
end

function jump_to_moment()
  if capencours then
    remindin()
    return
  end
  local sel,ri,isel
  sel,ri=oneselected(1)
  if sel then
    if ri>0 then 
      local stemp=tmsorted[ri]
      currmom=ri
      currmomch=string.sub(stemp,1,dectomomname)
      info_med2:set_text("<i><font color=darkblue>"..stemp.."</font></i>",1,6,4)
    end
    display_moments(0)
  else
    if (ri==0) and (nmoms>0) then
      currmom=currmom+1
      if (currmom<=0) or (currmom>nmoms) then
        currmom=1
      end
      sel=tmsorted[currmom]
      currmomch=string.sub(sel,1,dectomomname)
      info_med2:set_text("<i><font color=darkblue>"..sel.."</font></i>",1,6,4)
    else
      return
    end
  end
  cleanerr()
  isel=findmo(sel)
  exitpause()
  if vlc_version<4 then
    vlc.var.set(input,"position",tmompos[isel])
  else
    vlc.player.seek_by_pos_absolute(tmompos[isel])
  end
end

function remove_moment()
  if capencours then
    remindin()
    return
  end
  local sel,ri
  sel,ri=oneselected(1)
  if afferr then
    return
  end 
  local isel=findmo(sel)
  if isel>0 then
    tmomname[isel]=tmomname[nmoms]
    tmompos[isel]=tmompos[nmoms]
    tmomch[isel]=tmomch[nmoms]
    tmomem[isel]=tmomem[nmoms]
    nmoms=nmoms-1
    if nmoms<1 then
      table_save_lmom[mediumidx]="nil"
    else
      table_save_lmom[mediumidx]=table.concat(tmomem,"",1,nmoms)
    end
    simodif=true
    if (ri>0) and (currmom>=ri) then
      if currmom==ri then
        if ri>1 then
         info_med2:set_text("<s><i><font color=darkblue>"..tmsorted[ri].."</font></i></s>",1,6,4)
         currmomch=string.sub(tmsorted[ri-1],1,dectomomname)
        else
          info_med2:set_text("",1,6,4)
        end
      end
      currmom=currmom-1
    end
    local s=table.remove(tmsorted)
    cleanerr() 
  end
  display_moments(1)
  exitpause()
end

function memosave()
  if capencours then
    remindin()
    return
  end
  local doxspf=false
  local dest
  local file
  local k
  local tms={}
  k=0
  while k<nmoms do
    k=k+1
    tms[k]=rawget(tmsorted,k)
  end
  if check_xspf then
    doxspf=check_xspf:get_checked()
    main_layout:del_widget(check_xspf)
    check_xspf=nil
  end
  main_layout:del_widget(imp_button)
  imp_button=nil
  printd=true
  if not(doxspf) then
    dest=vlc.config.userdatadir().."/Memos.txt"
    file=io.open(dest,"a+")
    file:write(os.date("%Y/%m/%d %H:%M").."\n")
    file:write(medium_name.."\n")
    k=0
    while k<nmoms do
     k=k+1
     file:write(tms[k].."\n")
    end
    if minsec_display>0 then
      file:write(formatpos(1).." - THE END -\n")
    else
      file:write("1000 - THE END -\n")
    end
    file:write("================\n")
    file:flush()
    file:close()
    return
  end
  if string.find(medium_uri,"<") or string.find(medium_uri,"&") then  -- playlist killers
    return
  end
  dest=vlc.config.userdatadir().."/Memos.xspf"

  -- Step 1 : start with existing playlist or root structure
  local filex=io.open(dest,"r+")
  if filex then
    filex:seek("end",-13)  -- </playlist>
  else
    filex=io.open(dest,"w+")
    filex:write('<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<playlist xmlns=\"http://xspf.org/ns/0/\" ')
    filex:write('xmlns:vlc=\"http://www.videolan.org/vlc/playlist/ns/0/\" version=\"1\">\n')
    filex:write("<title>Momtrak_playlist [started "..os.date("%Y/%m/%d %H:%M").."]</title>\n")
  end

  -- Step 2 : add new playlist
  filex:write("<trackList>\n")
  local kk,mtime
  local mame,chtime
  local chext='<extension application=\"http://www.videolan.org/vlc/playlist/0\">\n'
  local t1000=tdur/1000
  if nmoms==0 then
      mame=string.gsub(medium_name,"<","_")
      mame=string.gsub(mame,"&","_")
      filex:write("<track>\n<title>"..mame.."</title>\n","<location>"..medium_uri.."</location>\n")
      filex:write(chext)
      filex:write("<vlc:id>0</vlc:id>\n<vlc:option>start-time=0</vlc:option>\n</extension>\n</track>\n")
  else
      kk=0
      k=0
      while kk<nmoms do
         kk=kk+1
         mame=string.sub(tms[kk],dectomomname)
         if #(mame)>50 then mame=string.sub(mame,1,48)..".." end
         mame=string.gsub(mame,"<","_")
         mame=string.gsub(mame,"&","_")
         chtime=string.sub(tms[kk],1,(dectomomname-2))
         if minsec_display>0 then
           if string.sub(chtime,1,1)==":" then
             mtime=math.floor(tdur)
           else
mtime=tonumber(string.sub(chtime,7,8))+60*tonumber(string.sub(chtime,4,5))+3600*tonumber(string.sub(chtime,1,2))
           end
         else
             mtime=math.floor(t1000*tonumber(chtime))
         end
filex:write("<track>\n<title>"..mame.."</title>\n<location>"..medium_uri.."</location>\n")
filex:write(chext)
filex:write("<vlc:id>",k,"</vlc:id>\n<vlc:option>start-time=",mtime,"</vlc:option>\n</extension>\n</track>\n")
         k=k+1
      end
  end
  filex:write("</trackList>\n")
  filex:write(chext)
  mame=string.gsub(medium_name,"<","_")
  mame=string.gsub(mame,"&","_")
  filex:write('<vlc:node title=\"'..mame..'\">\n')
  if nmoms==0 then
      filex:write('<vlc:item tid=\"0\" />\n')
  else
      k=0
      while k<nmoms do
        filex:write('<vlc:item tid=\"',k,'\" />\n')
        k=k+1
      end
  end
  filex:write("</vlc:node>\n</extension> \n</playlist>\n")
  filex:flush()
  filex:close()
end

function showkerr(ka)
  local chi
  afferr=true
  if ka==7 then chi="ONE selection please !"
  else
    chi="Naming rules : 2 chars min, NO "
    if ka==2 then
      chi=chi.."~ *&"
    else
      chi=chi.."~"
    end
  end
  chi="<b><font color=darkred>"..chi.."</font></b>"
  err_label=main_layout:add_label(chi,1,2,3)
end
