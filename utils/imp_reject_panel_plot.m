function h = imp_reject_panel_plot(ax, tt, Dk, Ak, ref, col, resp_s, aPreOnly)
%IMP_REJECT_PANEL_PLOT  One disturbance-rejection trial panel.
%
%   THE ONE PLACE this panel is drawn. It was a local function inside
%   internal_model_principle.m until 2026-08-13, when the batch version
%   (imp_reject_gallery_all.m) needed the same picture -- and that file's own header
%   already warns what happens when the two rejection streams keep private copies
%   ("Until 2026-08-10 this section carried an inline COPY of the rho lambdas, so the
%   two streams could silently drift apart. Do not re-inline them."). Same rule here:
%   change the panel HERE, never in a caller.
%
%   Three traces, and the reason for each:
%     D = G        disturbance / stim-blind contra prediction        (gray, solid)
%     A (no ref)   raw actual ipsi, NOT ref-subtracted               (light dashed)
%                  -> pre-stim A ~ G ~ 0, which is the visual proof that the
%                     reference is effectively zero before the laser; post-stim it
%                     shows the true suppression in absolute %dF/F.
%     E = A - ref  subdued error, the metric's numerator. Drawn lighter pre-stim to
%                  mark the ref-zero baseline, full condition colour post-stim.
%
%   ax       target axes                    tt      time vector (s), 0 = laser onset
%   Dk, Ak   one trial's D and A traces      ref     reference level (%dF/F)
%   col      condition colour                resp_s  stim duration (s), sets the shading
%   aPreOnly (default false) draw the raw-A dashed trace pre-stim only
%
%   Returns h with fields .D .A .E (line handles, for a legend).

if nargin<8 || isempty(aPreOnly), aPreOnly=false; end
hold(ax,'on');
Ek = Ak - ref;  ipre = tt<0;  ipost = ~ipre;
lcol = col + 0.55*([1 1 1]-col);                            % lighter tint of the condition colour
if aPreOnly, aY = Ak(ipre); else, aY = Ak; end             % A samples that will be shown
yl = [min([Dk aY Ek])-1, max([Dk aY Ek])+1];
patch(ax,[1 resp_s resp_s 1],[yl(1) yl(1) yl(2) yl(2)],[.92 .92 .92],'EdgeColor','none','HandleVisibility','off');
yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
h.D = plot(ax,tt,Dk,'-','Color',[.45 .45 .45],'LineWidth',1.2,'DisplayName','disturbance D = contra pred');
if aPreOnly
    h.A = plot(ax,tt(ipre),Ak(ipre),'--','Color',lcol,'LineWidth',1.1,'DisplayName','actual A (no ref, pre-stim)');
else
    h.A = plot(ax,tt,Ak,'--','Color',lcol,'LineWidth',1.1,'DisplayName','actual A (no ref)');
end
plot(ax,tt(ipre),Ek(ipre),'-','Color',lcol,'LineWidth',1.2,'HandleVisibility','off');   % pre-stim error (ref-zero baseline)
h.E = plot(ax,tt(ipost),Ek(ipost),'-','Color',col,'LineWidth',1.6,'DisplayName','subdued error E = A - ref');
xlim(ax,[tt(1) tt(end)]); ylim(ax,yl); box(ax,'off'); set(ax,'TickDir','out');
end
