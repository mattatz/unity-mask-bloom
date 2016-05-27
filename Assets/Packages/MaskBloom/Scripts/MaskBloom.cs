using UnityEngine;
using System.Collections;

namespace mattatz.MaskBloom {

    [RequireComponent (typeof(Camera) )]
    public class MaskBloom : MonoBehaviour {

        public enum BloomType {
            Screen,
            Add
        };

        [SerializeField] BloomType type = BloomType.Screen;
        [SerializeField] Shader shader; // assign mattatz/MaskBloom shader.
        Material material;

        [SerializeField] int
            blurIterations = 3,
            blurDownSample = 2;

        [SerializeField] float
            bloomIntensity = 1.0f;

        [SerializeField] bool debug;

        void Start() {
            material = new Material(shader);
        }

        void Update() {
            blurIterations = Mathf.Max(1, blurIterations);
            blurDownSample = Mathf.Max(0, blurDownSample);
            bloomIntensity = Mathf.Max(0f, bloomIntensity);
        }

        void OnRenderImage(RenderTexture src, RenderTexture dst) {

            // Gaussian Blur
            var downSampled = DownSample(src, blurDownSample);
            Blur(downSampled, blurIterations);

            if (debug) {
                Graphics.Blit(downSampled, dst);
                RenderTexture.ReleaseTemporary(downSampled);
                return;
            }

            // Bloom
            material.SetFloat("_Intensity", bloomIntensity);
            material.SetTexture("_BlurTex", downSampled);

            switch (type)
            {
                case BloomType.Screen:
                    Graphics.Blit(src, dst, material, 4);
                    break;

                case BloomType.Add:
                    Graphics.Blit(src, dst, material, 5);
                    break;

                default:
                    Graphics.Blit(src, dst, material, 4);
                    break;
            }

            RenderTexture.ReleaseTemporary(downSampled);
        }

        public void Blur(RenderTexture src, int nIterations) {
            var tmp0 = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
            var tmp1 = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
            var iters = Mathf.Clamp(nIterations, 0, 10);

            Graphics.Blit(src, tmp0);
            for (var i = 0; i < iters; i++) {
                for (var pass = 2; pass < 4; pass++) {
                    tmp1.DiscardContents();
                    tmp0.filterMode = FilterMode.Bilinear;
                    Graphics.Blit(tmp0, tmp1, material, pass);
                    var tmpSwap = tmp0;
                    tmp0 = tmp1;
                    tmp1 = tmpSwap;
                }
            }
            Graphics.Blit(tmp0, src);

            RenderTexture.ReleaseTemporary(tmp0);
            RenderTexture.ReleaseTemporary(tmp1);
        }

        public RenderTexture DownSample(RenderTexture src, int lod) {
            var dst = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
            src.filterMode = FilterMode.Bilinear;
            Graphics.Blit(src, dst);

            for (var i = 0; i < lod; i++) {
                var tmp = RenderTexture.GetTemporary(dst.width >> 1, dst.height >> 1, 0, dst.format);
                dst.filterMode = FilterMode.Bilinear;
                Graphics.Blit(dst, tmp, material, 0);
                RenderTexture.ReleaseTemporary(dst);
                dst = tmp;
            }

            var mask = RenderTexture.GetTemporary(dst.width, dst.height, 0, dst.format);
            mask.filterMode = FilterMode.Bilinear;
            Graphics.Blit(dst, mask, material, 1); // masking
            RenderTexture.ReleaseTemporary(dst);
            return mask;
        }

    }

}


