#include "silk_decoder.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "silk/interface/SKP_Silk_SDK_API.h"

#define MAX_BYTES_PER_FRAME     1024
#define MAX_INPUT_FRAMES        5
#define MAX_FRAME_LENGTH        480
#define FRAME_LENGTH_MS         20
#define MAX_API_FS_KHZ          48
#define MAX_LBRR_DELAY          2

#ifdef _SYSTEM_IS_BIG_ENDIAN
/* Function to convert a little endian int16 to a */
/* big endian int16 or vica verca                 */
void swap_endian(
    SKP_int16       vec[],
    SKP_int         len
)
{
    SKP_int i;
    SKP_int16 tmp;
    SKP_uint8 *p1, *p2;

    for( i = 0; i < len; i++ ){
        tmp = vec[ i ];
        p1 = (SKP_uint8 *)&vec[ i ]; p2 = (SKP_uint8 *)&tmp;
        p1[ 0 ] = p2[ 1 ]; p1[ 1 ] = p2[ 0 ];
    }
}
#endif

/**
 * @brief 解码 silk v3 文件.
 *
 * @param input_path 输入的 silk v3 比特流文件路径.
 * @param output_path 输出的 pcm 文件路径.
 * @param sample_rate 解码后的 pcm 采样率 in Hz.
 * @return int 0 表示成功, -1 表示失败.
 */
FFI_PLUGIN_EXPORT int decode_silk_file(const char *input_path, const char *output_path, int sample_rate) {
    size_t counter;
    SKP_int16 ret, len, tot_len;
    SKP_int16 nBytes;
    SKP_uint8 payload[MAX_BYTES_PER_FRAME * MAX_INPUT_FRAMES * (MAX_LBRR_DELAY + 1)];
    SKP_int16 out[((FRAME_LENGTH_MS * MAX_API_FS_KHZ) << 1) * MAX_INPUT_FRAMES];
    FILE *bitInFile, *speechOutFile;
    SKP_int32 decSizeBytes;
    void *psDec;
    SKP_SILK_SDK_DecControlStruct DecControl;

    bitInFile = fopen(input_path, "rb");
    if (bitInFile == NULL) {
        fprintf(stderr, "错误: 无法打开输入文件 %s\n", input_path);
        return -1;
    }

    speechOutFile = fopen(output_path, "wb");
    if (speechOutFile == NULL) {
        fprintf(stderr, "错误: 无法打开输出文件 %s\n", output_path);
        fclose(bitInFile);
        return -1;
    }

    /* 检查 Silk 文件头  */
    {
        char header_buf[11] = {0};
        const char *amr_header = "#!SILK_V3";
        const char *silk_header = "!SILK_V3";
        long header_offset = 0;
        int header_found = 0;

        fseek(bitInFile, 0, SEEK_SET);

        size_t bytes_read = fread(header_buf, 1, 10, bitInFile);
        if (bytes_read < strlen(silk_header)) { // 文件长度至少要够一个标准头
            fprintf(stderr, "错误: 文件太小，无法包含有效的文件头。\n");
            exit(-1);
        }

        if (strncmp(header_buf, amr_header, strlen(amr_header)) == 0) {
            header_found = 1;
            header_offset = strlen(amr_header);
        } else if (strncmp(header_buf, silk_header, strlen(silk_header)) == 0) {
            header_found = 1;
            header_offset = strlen(silk_header);
        } else if (bytes_read > strlen(amr_header) &&
                   strncmp(header_buf + 1, amr_header, strlen(amr_header)) == 0) {
            header_found = 1;
            header_offset = strlen(amr_header) + 1;
        } else if (bytes_read > strlen(silk_header) &&
                   strncmp(header_buf + 1, silk_header, strlen(silk_header)) == 0) {
            header_found = 1;
            header_offset = strlen(silk_header) + 1;
        }

        if (header_found) {

            fseek(bitInFile, header_offset, SEEK_SET);
        } else {

            fprintf(stderr, "错误: 找不到有效的SILK V3文件头。文件开头的实际内容是: %s\n",
                    header_buf);
            fclose(bitInFile);
            fclose(speechOutFile);
            return -1;
        }
    }

    DecControl.API_sampleRate = sample_rate;
    DecControl.framesPerPacket = 1;


    ret = SKP_Silk_SDK_Get_Decoder_Size(&decSizeBytes);
    if (ret) {
        fprintf(stderr, "\nSKP_Silk_SDK_Get_Decoder_Size 返回 %d", ret);
        fclose(bitInFile);
        fclose(speechOutFile);
        return -1;
    }
    psDec = malloc(decSizeBytes);

    ret = SKP_Silk_SDK_InitDecoder(psDec);
    if (ret) {
        fprintf(stderr, "\nSKP_Silk_InitDecoder 返回 %d", ret);
        free(psDec);
        fclose(bitInFile);
        fclose(speechOutFile);
        return -1;
    }

    while (1) {
        counter = fread(&nBytes, sizeof(SKP_int16), 1, bitInFile);
#ifdef _SYSTEM_IS_BIG_ENDIAN
        swap_endian(&nBytes, 1);
#endif
        if (nBytes < 0 || counter < 1) {
            break;
        }

        counter = fread(payload, sizeof(SKP_uint8), nBytes, bitInFile);
        if ((SKP_int16) counter < nBytes) {
            break;
        }

        SKP_int16 *outPtr = out;
        tot_len = 0;

        do {
            ret = SKP_Silk_SDK_Decode(psDec, &DecControl, 0, payload, nBytes, outPtr, &len);
            if (ret) {
                fprintf(stderr, "\nSKP_Silk_SDK_Decode returned %d", ret);
            }

            outPtr += len;
            tot_len += len;
        } while (DecControl.moreInternalDecoderFrames);

#ifdef _SYSTEM_IS_BIG_ENDIAN
        swap_endian(out, tot_len);
#endif
        fwrite(out, sizeof(SKP_int16), tot_len, speechOutFile);
    }

    free(psDec);

    fclose(speechOutFile);
    fclose(bitInFile);

    return 0;
}
