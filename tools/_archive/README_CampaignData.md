# generated/CampaignData.gd (보관)

`class_name CampaignData` 가 두 파일에 선언돼 있었다.

    generated/CampaignData.gd          ← 옛 사본 (여기)
    scripts3d/campaign/CampaignData.gd ← 현재 쓰는 것

Godot 은 같은 class_name 중 하나만 등록하는데, 옛 사본이 이겨서
새로 추가한 `Stage.puzzle` 필드가 런타임에 사라졌다
(퍼즐 검증에서 "Invalid access to property 'puzzle'" 로 드러남).

도구(AI Asset Factory)는 `scripts3d/campaign/CampaignData.gd` 로 내보낸다.
generated/ 쪽은 쓰이지 않으므로 여기로 옮겼다.
