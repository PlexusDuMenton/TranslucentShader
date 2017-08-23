using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

enum RenderingMode
{
    Opaque, Cutout, Fade, Transparent
}

struct RenderingSettings
{
    public RenderQueue queue;
    public string renderType;
    public BlendMode srcBlend, dstBlend;
    public bool zWrite;



    public static RenderingSettings[] modes = {
            new RenderingSettings() {
                queue = RenderQueue.Geometry,
                renderType = "",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings() {
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings() {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
				srcBlend = BlendMode.SrcAlpha,
				dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            }
            ,
            new RenderingSettings() {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            }
        };
}

public class TranslucentShaderGUI : ShaderGUI{

    MaterialEditor editor;
    MaterialProperty[] properties;
    Material target;
    public bool invertTransNormal;
    public bool invertNormal;

    public override void OnGUI(
        MaterialEditor editor, MaterialProperty[] properties
    )
    {
        this.target = editor.target as Material;
        this.editor = editor;
        this.properties = properties;
        Main();
        DoTranslucent();
        Secondary();

    }

    MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }

    static GUIContent staticLabel = new GUIContent();

    static GUIContent MakeLabel(
        MaterialProperty property, string tooltip = null
    )
    {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }
    static GUIContent MakeLabel(
        string text, string tooltip = null
    )
    {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    bool IsKeywordEnabled(string keyword)
    {
        return target.IsKeywordEnabled(keyword);
    }
    void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            target.EnableKeyword(keyword);
        } else
        {
            target.DisableKeyword(keyword);
        }
    }

    void RecordAction(string label)
    {
        editor.RegisterPropertyChangeUndo(label);
    }

    //o=-=-=(===============- MightySword ! 

    void DoNormals()
    {
        MaterialProperty map = FindProperty("_NormalMap");
        editor.TexturePropertySingleLine(MakeLabel(map), map,
            map.textureValue ? FindProperty("_BumpScale") : null
        );
    }


    void DoMetallic()
    {

        MaterialProperty map = FindProperty("_MetallicMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Metallic"), map,
            FindProperty("_Metallic")
        );
    }

    void DoEmissive()
    {

        MaterialProperty map = FindProperty("_EmissionMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Emission"), map,
            FindProperty("_Emission")
        );
    }

    void DoSmoothness()
    {
        MaterialProperty map = FindProperty("_SmoothnessMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Smoothness"), map,
            FindProperty("_Smoothness")
        );
    }

    void DoOclussion()
    {
        MaterialProperty map = FindProperty("_OcclusionMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Occlusion"), map,
            FindProperty("_OcclusionStrength")
        );
    }

    void DoTranslucent()
    {
        GUILayout.Space(5);
        GUILayout.Label("Translucency", EditorStyles.boldLabel);
        MaterialProperty map = FindProperty("_TranslucencyMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Translucency"), map,
            FindProperty("_TranslucencyColor")
        );

        MaterialProperty sliderScale = FindProperty("_TranslucencyScale");
        MaterialProperty sliderPower = FindProperty("_TranslucencyPower");
        MaterialProperty sliderSSS = FindProperty("_SSS");

        editor.ShaderProperty(
             sliderScale,
             MakeLabel(sliderScale, "Translucency Intensity")
        );

        editor.ShaderProperty(
            sliderPower,
            MakeLabel(sliderPower, "Translucency Specular intensity")
        );

        editor.ShaderProperty(
            sliderSSS,
            MakeLabel(sliderSSS, "Increase / Reduce Translucency area")
        );
        invertTransNormal = IsKeywordEnabled("_INVERTNORMALTRANSLUCENT");
        invertNormal = IsKeywordEnabled("_INVERTNORMAL");
        invertTransNormal = EditorGUILayout.Toggle("Invert Translucent normal", invertTransNormal);
        
        SetKeyword("_INVERTNORMALTRANSLUCENT", invertTransNormal);
        invertNormal = EditorGUILayout.Toggle("Invert normal", invertNormal);

        SetKeyword("_INVERTNORMAL", invertNormal);
        
    }

    bool shouldShowAlphaCutoff;

    void DoRenderingMode()
    {
        RenderingMode mode = RenderingMode.Opaque;
        shouldShowAlphaCutoff = false;
        if (IsKeywordEnabled("_RENDERING_CUTOUT"))
        {
            shouldShowAlphaCutoff = true;
            mode = RenderingMode.Cutout;
        } else if (IsKeywordEnabled("_RENDERING_FADE"))
        {
            mode = RenderingMode.Fade;
        } else if (IsKeywordEnabled("_RENDERING_TRANSPARENT"))
        {
            mode = RenderingMode.Transparent;
        }

        EditorGUI.BeginChangeCheck();
        mode = ( RenderingMode ) EditorGUILayout.EnumPopup(
            MakeLabel("Rendering Mode"), mode
        );
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderingMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderingMode.Fade);
            SetKeyword(
				"_RENDERING_TRANSPARENT", mode == RenderingMode.Transparent
			);

            RenderingSettings settings = RenderingSettings.modes[( int ) mode];
            foreach (Material m in editor.targets)
            {
                m.renderQueue = ( int ) settings.queue;
                m.SetOverrideTag("RenderType", settings.renderType);
                m.SetInt("_SrcBlend", ( int ) settings.srcBlend);
                m.SetInt("_DstBlend", ( int ) settings.dstBlend);
                m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
            }

        }

        
    }



    void Main()
    {
        DoRenderingMode();
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);

        MaterialProperty mainTex = FindProperty("_MainTex");
        editor.TexturePropertySingleLine(
            MakeLabel(mainTex, "Albedo (RGB)"), mainTex, FindProperty("_Tint")
        );
        
        if (mainTex.textureValue&& shouldShowAlphaCutoff) {
            EditorGUI.indentLevel += 3;
            MaterialProperty alpha = FindProperty("_AlphaCutoff");
            editor.ShaderProperty(
                alpha,
                MakeLabel(alpha, "Alpha (RGB)")
            );
            EditorGUI.indentLevel -= 3;
        }
        DoOclussion();

        DoMetallic();
        DoSmoothness();
        

        DoNormals();

        DoEmissive();
        editor.TextureScaleOffsetProperty(mainTex);  

    }

    void Secondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);

        MaterialProperty detailTex = FindProperty("_DetailTex");
        editor.TexturePropertySingleLine(
            MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex
        );
        DoSecondaryNormals();
        editor.TextureScaleOffsetProperty(detailTex);
    }

    void DoSecondaryNormals()
    {
        MaterialProperty map = FindProperty("_DetailNormalMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map), map,
            map.textureValue ? FindProperty("_DetailBumpScale") : null
        );
    }
}
