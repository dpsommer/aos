<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<gameSystem id="sys" name="Test System" revision="1" xmlns="http://www.battlescribe.net/schema/gameSystemSchema">
  <publications>
    <publication id="pub-bt" name="Battletome: Testers"/>
    <publication id="pub-soa" name="Scourge of Aqshy"/>
    <publication id="pub-leg" name="Warhammer Legends"/>
    <publication id="pub-core" name="Core Rules"/>
    <publication id="pub-gh" name="General's Handbook 2025-26"/>
  </publications>
  <forceEntries>
    <forceEntry id="f-army" name="Test Army" hidden="false"/>
    <forceEntry id="f-alpha" name="Alpha Company">
      <costs><cost name="pts" typeId="points" value="250.0"/></costs>
      <modifiers>
        <modifier type="set" field="hidden" value="true">
          <conditions>
            <condition type="notInstanceOf" childId="cat-ror" field="selections" scope="roster" value="1"/>
            <condition type="notInstanceOf" childId="cat-testers" field="selections" scope="roster" value="1"/>
          </conditions>
        </modifier>
      </modifiers>
    </forceEntry>
    <forceEntry id="f-old" name="Old Guard [LEGENDS]">
      <costs><cost name="pts" typeId="points" value="100.0"/></costs>
      <modifiers>
        <modifier type="set" field="hidden" value="true">
          <conditionGroups>
            <conditionGroup type="and">
              <conditions>
                <condition type="notInstanceOf" childId="cat-ror" field="selections" scope="roster" value="1"/>
              </conditions>
              <conditionGroups>
                <conditionGroup type="or">
                  <conditions>
                    <condition type="notInstanceOf" childId="cat-testers" field="selections" scope="roster" value="1"/>
                    <condition type="notInstanceOf" childId="cat-shared" field="selections" scope="roster" value="1"/>
                  </conditions>
                </conditionGroup>
              </conditionGroups>
            </conditionGroup>
          </conditionGroups>
        </modifier>
      </modifiers>
    </forceEntry>
    <forceEntry id="f-pathless" name="Pathless Band">
      <costs><cost name="pts" typeId="points" value="60.0"/></costs>
      <modifiers>
        <modifier type="set" field="hidden" value="true">
          <conditions>
            <condition type="notInstanceOf" childId="cat-ror" field="selections" scope="roster" value="1"/>
          </conditions>
        </modifier>
      </modifiers>
    </forceEntry>
  </forceEntries>
</gameSystem>
